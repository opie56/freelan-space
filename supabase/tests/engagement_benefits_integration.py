from admin_test_support import enroll_test_admins, test_claims
from concurrent.futures import ThreadPoolExecutor
import json, subprocess, sys, unittest
DB=sys.argv[1]; sys.argv=sys.argv[:1]
O='c0000000-0000-4000-8000-000000000001'; U='c0000000-0000-4000-8000-000000000002'; X='c0000000-0000-4000-8000-000000000003'; A='c0000000-0000-4000-8000-000000000004'; V='c0000000-0000-4000-8000-000000000005'; C='c1000000-0000-4000-8000-000000000001'
def sql(q,uid=None,role='authenticated',fail=False):
 prefix=f"set role {role}; select set_config('request.jwt.claim.sub','{uid}',false); " if uid else (f'set role {role}; ' if role!='owner' else '')
 p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+q],capture_output=True,text=True)
 if fail:
  if p.returncode==0: raise AssertionError('Unexpected success')
 elif p.returncode: raise AssertionError(p.stderr)
 return (p.stdout.strip().splitlines() or [''])[-1]
class Engagement(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  sql(f"""insert into auth.users(id,email) values('{O}','o@example.test'),('{U}','u@example.test'),('{X}','x@example.test'),('{A}','a@example.test'),('{V}','v@example.test');
  insert into public.admin_members(user_id,role) values('{A}','editor'),('{V}','viewer');
  insert into public.wallets(id,balance) values('{O}',10),('{U}',10),('{X}',10);
  insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining,\"createdAt\") values('{C}','{O}','like','https://instagram.com/p/TEST/','active',4,4,now()-interval '2 minutes');
  insert into public.submission_history(submission_id,campaign_id,user_id,status,submitted_at,reviewed_at) values(gen_random_uuid(),'{C}','{U}','approved',now(),now()),(gen_random_uuid(),'{C}','{X}','approved',now(),now());""",role='owner')
  enroll_test_admins(DB)
 def test_01_challenge_atomic_cap(self):
  sql('select public.admin_set_weekly_challenge(1,2,2)',V,fail=True)
  sql('select public.admin_set_weekly_challenge(1,2,2)',A)
  def attempt(u):
   try: return sql('select public.claim_weekly_challenge()',u)
   except AssertionError: return 'rejected'
  with ThreadPoolExecutor(max_workers=2) as pool: result=list(pool.map(attempt,[U,X]))
  self.assertEqual(sorted(result),['2','rejected'])
  self.assertEqual(sql("select sum(amount) from public.coin_ledger where reason='weekly_challenge'",role='owner'),'2')
  sql('select public.claim_weekly_challenge()',U if result[0]=='2' else X,fail=True)
 def test_02_reminders_owner_and_once(self):
  sql(f"select public.set_task_saved('{C}',true)",U)
  sql(f"select public.set_saved_task_reminder('{C}',now()+interval '1 hour')",U)
  sql(f"select public.set_saved_task_reminder('{C}',now()+interval '1 hour')",X,fail=True)
  sql('select public.dispatch_saved_task_reminders()',U,fail=True)
  sql('update growth_internal.saved_task_reminders set remind_at=now()-interval \'1 minute\'',role='owner')
  self.assertEqual(sql('select public.dispatch_saved_task_reminders()',role='service_role'),'1')
  self.assertEqual(sql('select public.dispatch_saved_task_reminders()',role='service_role'),'0')
  self.assertEqual(sql("select count(*) from public.notifications where kind='saved_task_reminder'",U),'1')
 def test_03_progress_and_low_balance(self):
  sql('select public.set_user_extra_alerts(true,5)',O)
  sql(f"update public.campaigns set remaining=2 where id='{C}'",role='owner')
  sql(f"update public.campaigns set remaining=0,status='completed' where id='{C}'",role='owner')
  sql(f"update public.wallets set balance=4 where id='{O}'",role='owner')
  self.assertEqual(sql("select count(*) from public.notifications where kind in ('campaign_progress_50','campaign_progress_100','low_balance')",O),'3')
  sql(f"update public.wallets set balance=3 where id='{O}'",role='owner')
  self.assertEqual(sql("select count(*) from public.notifications where kind='low_balance'",O),'1')
 def test_04_help_and_insights_isolation(self):
  sql("select public.admin_save_help(null,'Title','Answer',true)",V,fail=True)
  sql("select public.admin_save_help(null,'Title','Answer',true)",A)
  self.assertEqual(sql('select count(*) from public.user_help_articles()',U),'1')
  info=json.loads(sql('select public.monthly_coin_insights()',U))
  self.assertGreaterEqual(info['bonus'],0)
  self.assertEqual(info,json.loads(sql("set timezone='America/New_York'; select public.monthly_coin_insights()",U)))
  self.assertEqual(json.loads(sql('select public.weekly_challenge_status()',U)),json.loads(sql("set timezone='America/New_York'; select public.weekly_challenge_status()",U)))
  sql('select * from growth_internal.weekly_challenge_settings',U,fail=True)
 def test_05_notification_preferences_and_archive(self):
  sql('select public.set_user_notification_preferences(false,false,true)',O)
  sql(f"update public.campaigns set remaining=4,status='active' where id='{C}'",role='owner')
  sql(f"update public.campaigns set remaining=2 where id='{C}'",role='owner')
  sql(f"update public.wallets set balance=10 where id='{O}'",role='owner')
  sql(f"update public.wallets set balance=4 where id='{O}'",role='owner')
  self.assertEqual(sql(f"select count(*) from public.notifications where user_id='{O}' and kind in ('campaign_progress_50','low_balance') and not show_in_app and not deliver_push",role='owner'),'2')
  winner=sql('select user_id from growth_internal.weekly_challenge_grants limit 1',role='owner')
  sql(f"delete from auth.users where id='{winner}'",role='owner')
  self.assertEqual(sql('select sum(total) from growth_internal.weekly_challenge_totals',role='owner'),'2')
  self.assertEqual(sql(f"select jsonb_array_length(snapshot->'growth_internal.weekly_challenge_grants') from growth_internal.deleted_account_archives where user_id='{winner}'",role='owner'),'1')
 def test_06_admin_controls(self):
  keys=['weekly_challenges','resubmit_help','saved_task_reminders','monthly_coin_insights','campaign_copy','campaign_progress_alerts','low_balance_alerts','editable_help']
  sql("select public.admin_set_user_feature('weekly_challenges',false)",V,fail=True)
  for key in keys: sql(f"select public.admin_set_user_feature('{key}',false)",A)
  sql('select public.weekly_challenge_status()',O,fail=True)
  sql('select public.monthly_coin_insights()',O,fail=True)
  self.assertEqual(sql('select count(*) from public.user_help_articles()',O),'0')
  self.assertEqual(sql('select public.dispatch_saved_task_reminders()',role='service_role'),'0')
  for key in keys: sql(f"select public.admin_set_user_feature('{key}',true)",A)
if __name__=='__main__':unittest.main(verbosity=2)
