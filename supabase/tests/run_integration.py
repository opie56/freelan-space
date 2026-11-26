"""Replay migrations and current-contract tests in private local PostgreSQL DBs.

Usage: python3 supabase/tests/run_integration.py [--socket /var/run/postgresql]
Requires local PostgreSQL superuser access. Never accepts a destination database
or TCP host; all fixtures and destructive tests run in newly created databases.
Historical tests for superseded PIN/claim contracts are intentionally excluded.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / 'supabase/tests'
MIGRATIONS = sorted((ROOT / 'supabase/migrations').glob('*.sql'))
HISTORICAL = {
    'integration.py', 'review_integration.py', 'admin_integration.py',
    'profile_integration.py', 'action_controls_integration.py',
}
UPGRADE_TEST = 'random_identifiers_push_integration.py'
HISTORY_UPGRADE_TEST = 'wallet_history_upgrade_integration.py'
CAMPAIGN_UPGRADE_TEST = 'campaign_publication_upgrade_integration.py'
INSTAGRAM_UPGRADE_TEST = 'manual_instagram_upgrade_integration.py'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--socket', default='/var/run/postgresql')
    parser.add_argument('--port', type=int, default=5432)
    args = parser.parse_args()
    if not Path(args.socket).is_absolute() or not Path(args.socket).is_dir():
        parser.error('--socket must be an existing absolute Unix socket directory')
    env = dict(os.environ, PGHOST=args.socket, PGPORT=str(args.port), PGOPTIONS='')
    for key in ('PGHOSTADDR', 'PGSERVICE', 'PGSERVICEFILE', 'PGDATABASE'):
        env.pop(key, None)
    prefix = 'freelan_test_' + uuid.uuid4().hex[:12]
    databases = []

    def run(command, **kwargs):
        return subprocess.run(command, env=env, cwd=ROOT, check=True, **kwargs)

    def sql(db, statement):
        return run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', db],
                   input=statement, text=True, stdout=subprocess.PIPE).stdout.strip()

    def create(suffix, template=None):
        name = prefix + '_' + suffix
        run(['createdb', *(['-T', template] if template else []), name])
        databases.append(name)
        return name

    def bootstrap(db):
        # Roles are cluster-wide; reuse them without changing existing privileges.
        source = (TESTS / 'bootstrap.sql').read_text()
        for role in ('anon', 'authenticated'):
            source = source.replace(f'create role {role} nologin;', '')
        sql(db, source)
        sql(db, 'create table auth.mfa_factors(id uuid primary key, '
                'user_id uuid references auth.users(id), status text);')
        sql(db, (TESTS / 'app_updates_storage_bootstrap.sql').read_text())

    def seed_upgrade(db):
        sql(db, (TESTS / 'identifier_push_upgrade_fixture.sql').read_text())

    try:
        if sql('postgres', "select rolsuper from pg_roles where rolname=current_user") != 't':
            raise RuntimeError('Local PostgreSQL superuser access is required')
        for role in ('anon', 'authenticated', 'service_role', 'supabase_auth_admin'):
            sql('postgres', f"do $$ begin if not exists(select 1 from pg_roles where rolname='{role}') "
                            f"then create role {role} nologin; end if; end $$;")
        template = create('schema')
        bootstrap(template)
        for migration in MIGRATIONS:
            sql(template, migration.read_text())
        print(f'PASS: {len(MIGRATIONS)} migrations replayed', flush=True)
        suites = sorted(TESTS.glob('*integration.py'))
        suites = [p for p in suites if p.name not in HISTORICAL and p.name != Path(__file__).name]
        failures = []
        for index, suite in enumerate(suites):
            db = create(str(index), None if suite.name in (UPGRADE_TEST, HISTORY_UPGRADE_TEST, CAMPAIGN_UPGRADE_TEST, INSTAGRAM_UPGRADE_TEST) else template)
            if suite.name in (UPGRADE_TEST, HISTORY_UPGRADE_TEST, CAMPAIGN_UPGRADE_TEST, INSTAGRAM_UPGRADE_TEST):
                bootstrap(db)
                for migration in MIGRATIONS:
                    if suite.name == UPGRADE_TEST and migration.name.startswith('20261111143302_'):
                        seed_upgrade(db)
                    if suite.name == HISTORY_UPGRADE_TEST and migration.name.startswith('20261117040236_'):
                        sql(db, (TESTS / 'wallet_history_upgrade_fixture.sql').read_text())
                    if suite.name == CAMPAIGN_UPGRADE_TEST and migration.name.startswith('20261118192155_'):
                        sql(db, (TESTS / 'campaign_publication_upgrade_fixture.sql').read_text())
                    if suite.name == INSTAGRAM_UPGRADE_TEST and migration.name.startswith('20261126040000_'):
                        sql(db, (TESTS / 'manual_instagram_upgrade_fixture.sql').read_text())
                    sql(db, migration.read_text())
            print(f'RUN: {suite.name}', flush=True)
            result = subprocess.run([sys.executable, str(suite), db], env=env, cwd=ROOT)
            if result.returncode:
                failures.append(suite.name)
            run(['dropdb', db])
            databases.remove(db)
        # Extra SQL-only constraints and identifier-privacy coverage.
        sql(template, (TESTS / 'public_identifiers.sql').read_text())
        print(f'{len(suites) - len(failures)}/{len(suites)} current-contract suites passed; '
              'public identifier SQL passed', flush=True)
        if failures:
            print('Failed: ' + ', '.join(failures), file=sys.stderr)
        return bool(failures)
    finally:
        for db in reversed(databases):
            subprocess.run(['dropdb', '--if-exists', db], env=env, check=True)


if __name__ == '__main__':
    sys.exit(main())
