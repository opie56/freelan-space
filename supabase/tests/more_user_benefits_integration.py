"""Disposable database: reward idempotency, access, notifications and archive."""
from admin_test_support import enroll_test_admins, test_claims
from concurrent.futures import ThreadPoolExecutor
import json, subprocess, sys, unittest
DB=sys.argv[1];sys.argv=sys.argv[:1]
U='a0000000-0000-4000-8000-000000000001'; X='a0000000-0000-4000-8000-000000000002'; A='a0000000-0000-4000-8000-000000000003'; V='a0000000-0000-4000-8000-000000000004'; C='a1000000-0000-4000-8000-000000000001'
def sql(q,uid=None,role='authenticated',fail=False):
 prefix=f"set role {role}; select set_config('request.jwt.claim.sub','{uid}',false); " if uid else (f'set role {role}; ' if role!='owner' else '')
 p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+q],capture_output=True,text=True)
 if fail:
  if p.returncode==0: raise AssertionError('Unexpected success: '+q)
 elif p.returncode: raise AssertionError(p.stderr)
 return (p.stdout.strip().splitlines() or [''])[-1]
class Benefits(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  sql(f"""insert into auth.users(id,email) values ('{U}','u@example.test'),('{X}','x@example.test'),('{A}','a@example.test'),('{V}','v@example.test');
  insert into public.admin_members(user_id,role) values('{A}','editor'),('{V}','viewer');
  insert into public.wallets(id,balance) values('{U}',10),('{X}',10);
  insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining) values('{C}','{X}','like','https://instagram.com/p/TEST/','active',10,10);
  insert into public.submission_history(submission_id,campaign_id,user_id,status,submitted_at,reviewed_at) select gen_random_uuid(),'{C}','{U}','approved',now(),now() from generate_series(1,5);""",role='owner')
  enroll_test_admins(DB)
 def test_01_reward_access_and_idempotency(self):
  sql('select public.admin_set_benefit_rewards(2,2,3,0,0)',V,fail=True)
  sql('select public.admin_set_benefit_rewards(2,2,3,0,0)',U,fail=True)
  sql('select public.admin_set_benefit_rewards(2,2,3,0,0)',A)
  def attempt(_):
   try: sql('select public.claim_daily_bonus()',U);return True
   except AssertionError:return False
  with ThreadPoolExecutor(max_workers=8) as pool: self.assertEqual(sum(pool.map(attempt,range(8))),1)
  self.assertEqual(sql(f"select balance from public.wallets where id='{U}'",role='owner'),'12')
  sql('select public.claim_daily_bonus()',X,fail=True)
  self.assertEqual(sql('select public.claim_badge_bonus(5)',U),'3')
  sql('select public.claim_badge_bonus(5)',U,fail=True)
  sql('select public.claim_badge_bonus(10)',U,fail=True)
  self.assertEqual(sql(f"select count(*) from public.coin_ledger where user_id='{U}' and reason in ('daily_bonus','badge_bonus')",role='owner'),'2')
  sql("select public.admin_set_user_feature('daily_bonus',false)",A)
  sql('select public.claim_daily_bonus()',X,fail=True)
 def test_02_drafts_goals_statement_support(self):
  did=sql("select public.save_campaign_draft(null,'like','https://instagram.com/p/test','abc',2)",U)
  self.assertEqual(sql('select count(*) from public.user_campaign_drafts()',X),'0')
  sql(f"select public.save_campaign_draft('{did}','like','','',1)",X,fail=True)
  sql('select public.set_user_coin_goal(100)',U)
  self.assertEqual(sql('select public.user_coin_goal() is null',X),'t')
  self.assertEqual(json.loads(sql('select public.user_coin_goal()',U))['target'],100)
  self.assertEqual(sql("select count(*) from public.wallet_statement(now()-interval '1 day',now()+interval '1 day',0)",X),'0')
  self.assertEqual(sql("select count(*) from public.wallet_statement(now()-interval '1 day',now()+interval '1 day',0)",U),'2')
  sql("select * from public.wallet_statement(now()-interval '400 days',now(),0)",U,fail=True)
  sql(f"select public.support_reference_ticket('campaign','{C}','help')",U,fail=True)
  ref=sql(f"select id from public.coin_ledger where user_id='{U}' limit 1",role='owner')
  ticket=sql(f"select public.support_reference_ticket('transaction','{ref}','help')",U)
  self.assertEqual(sql(f"select count(*) from public.support_my_tickets() where id='{ticket}'",U),'1')
  sql("select public.admin_set_user_feature('campaign_drafts',false)",A)
  sql('select * from public.user_campaign_drafts()',U,fail=True)
 def test_03_saved_task_and_login_alerts(self):
  sql(f"insert into public.saved_tasks(user_id,campaign_id) values('{U}','{C}'); update public.campaigns set status='completed' where id='{C}';",role='owner')
  self.assertEqual(sql("select count(*) from public.notifications where kind='saved_task_unavailable' and saved_task_link='https://instagram.com/p/TEST/'",U),'1')
  sql(f"update auth.users set last_sign_in_at=now() where id='{U}';",role='owner')
  self.assertEqual(sql("select count(*) from public.notifications where kind='login_alert'",U),'1')
  sql("select public.admin_set_user_feature('login_alerts',false)",A)
  sql(f"update auth.users set last_sign_in_at=now()+interval '1 minute' where id='{U}';",role='owner')
  self.assertEqual(sql("select count(*) from public.notifications where kind='login_alert'",U),'1')
 def test_04_archive_new_business_records(self):
  sql(f"delete from auth.users where id='{U}'",role='owner')
  data=json.loads(sql(f"select snapshot::text from growth_internal.deleted_account_archives where user_id='{U}'",role='owner'))
  for name in ['daily_bonus_grants','badge_bonus_grants','campaign_drafts','user_coin_goals']:
   self.assertGreater(len(data['growth_internal.'+name]),0,name)
  self.assertEqual(sql('select total from growth_internal.daily_bonus_totals',role='owner'),'2')
if __name__=='__main__':unittest.main(verbosity=2)
