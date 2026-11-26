"""Manual Instagram account rules against the current schema."""
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
A = '20000000-0000-4000-8000-000000000001'
B = '20000000-0000-4000-8000-000000000002'


def run(query, user=None):
    prefix = (f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
              if user else '')
    return subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB,
                           '-c', prefix + query], capture_output=True, text=True)


class ManualInstagramTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = run(f"insert into auth.users(id) values ('{A}'),('{B}')")
        assert result.returncode == 0, result.stderr

    def test_duplicates_and_immutable_client_access(self):
        self.assertEqual(run("select public.add_instagram_account(' @Example ')", A).returncode, 0)
        self.assertNotEqual(run("select public.add_instagram_account('example')", A).returncode, 0)
        self.assertNotEqual(run("select public.add_instagram_account('@EXAMPLE')", B).returncode, 0)
        self.assertNotEqual(run("select public.add_instagram_account('bad handle')", B).returncode, 0)
        self.assertNotEqual(run("select public.remove_instagram_account('Example')", A).returncode, 0)
        self.assertNotEqual(run("update public.instagram_accounts set username='changed'", A).returncode, 0)
        self.assertNotEqual(run("delete from public.instagram_accounts", A).returncode, 0)
        self.assertEqual(run("select count(*) from public.instagram_accounts where username='Example'").stdout.strip(), '1')

    def test_concurrent_claims(self):
        def command(user):
            return ['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c',
                    f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
                    "select public.add_instagram_account('race.account');"]
        processes = [subprocess.Popen(command(user), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                     for user in (A, B)]
        for process in processes:
            process.communicate(timeout=15)
        self.assertEqual(sorted(p.returncode == 0 for p in processes), [False, True])
        self.assertEqual(run("select count(*) from public.instagram_accounts where lower(username)='race.account'").stdout.strip(), '1')


if __name__ == '__main__':
    unittest.main(verbosity=2)
