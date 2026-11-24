from admin_test_support import enroll_test_admins, test_claims
import json,subprocess,sys,unittest
from concurrent.futures import ThreadPoolExecutor
DB=sys.argv[1];sys.argv=sys.argv[:1]
O='d0000000-0000-4000-8000-000000000001';U='d0000000-0000-4000-8000-000000000002';X='d0000000-0000-4000-8000-000000000003';A='d0000000-0000-4000-8000-000000000004';V='d0000000-0000-4000-8000-000000000005';B='d0000000-0000-4000-8000-000000000006';C='d1000000-0000-4000-8000-000000000001';C2='d1000000-0000-4000-8000-000000000002';C3='d1000000-0000-4000-8000-000000000003'
def sql(q,uid=None,role='authenticated',fail=False):
 prefix=f"set role {role}; select set_config('request.jwt.claim.sub','{uid}',false); " if uid else (f'set role {role}; ' if role!='owner' else '')
 p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+q],capture_output=True,text=True)
 if fail:
  if p.returncode==0:raise AssertionError('Unexpected success: '+q)
 elif p.returncode:raise AssertionError(p.stderr)
 return (p.stdout.strip().splitlines() or [''])[-1]
class TaskClarity(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  sql(f"""insert into auth.users(id,email) values('{O}','o@example.test'),('{U}','u@example.test'),('{X}','x@example.test'),('{A}','a@example.test'),('{V}','v@example.test'),('{B}','b@example.test');
  insert into public.admin_members(user_id,role) values('{A}','editor'),('{V}','viewer');
  insert into public.wallets(id,balance) values('{O}',20),('{U}',20),('{X}',20),('{B}',20);
  insert into public.instagram_accounts(user_id,username) values('{B}','example');
  insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining,\"createdAt\") values('{C}','{O}','like','https://instagram.com/p/TEST/','active',3,3,now()-interval '10 minutes');""",role='owner')
  enroll_test_admins(DB)
 def test_01_instructions_preserve_checks(self):
  sql(f"select public.set_campaign_instructions('{C}','Proof details')",X,fail=True)
  sql(f"select public.set_campaign_instructions('{C}','Proof details')",O)
  self.assertEqual(sql(f"select task_instructions from public.campaigns where id='{C}'",U),'Proof details')
  sql("select public.create_campaign_with_instructions('like','example','https://instagram.com/p/TEST/',99,1,'details')",B,fail=True)
  cid=sql("select public.create_campaign_with_instructions('like','example','https://instagram.com/p/TEST/',1,1,'clear proof')",B)
  self.assertEqual(sql(f"select task_instructions from public.campaigns where id='{cid}'",B),'clear proof')
  self.assertEqual(sql(f"select balance from public.wallets where id='{B}'",B),'19')
 def test_02_notes_and_report_privacy(self):
  sql(f"select public.set_task_saved('{C}',true)",U)
  sql(f"select public.set_saved_task_note('{C}','private text')",U)
  self.assertEqual(sql(f"select public.user_saved_task_note('{C}')",U),'private text')
  self.assertEqual(sql(f"select public.user_saved_task_note('{C}') is null",X),'t')
  sql(f"select public.set_saved_task_note('{C}','bad')",X,fail=True)
  report=sql(f"select public.report_campaign('{C}','Reason')",U)
  self.assertEqual(sql('select count(*) from public.user_campaign_reports()',X),'0')
  self.assertEqual(sql('select status from public.user_campaign_reports()',U),'open')
  self.assertEqual(sql('select campaign_link from public.user_campaign_reports()',U),'https://instagram.com/p/TEST/')
  sql(f"select public.admin_resolve_report('{report}',false)",A)
  self.assertEqual(sql('select status from public.user_campaign_reports()',U),'resolved')
  sql(f"select public.set_task_saved('{C}',false)",U)
  self.assertEqual(sql(f"select public.user_saved_task_note('{C}') is null",U),'t')
 def test_03_optin_alerts_delay_and_dedup(self):
  sql("select public.set_preferred_tasks(array['like'])",U)
  sql("select public.set_preferred_tasks(array['follow'])",X)
  sql(f"update growth_internal.preferred_task_categories set enabled_at=now()-interval '5 minutes' where user_id in ('{U}','{X}')",role='owner')
  sql(f"""insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining,\"createdAt\") values('{C2}','{O}','like','https://instagram.com/p/TWO/','active',1,1,now()-interval '2 minutes'),('{C3}','{O}','like','https://instagram.com/p/THREE/','active',1,1,now());""",role='owner')
  sql('select public.dispatch_preferred_task_alerts()',U,fail=True)
  self.assertEqual(sql('select public.dispatch_preferred_task_alerts()',role='service_role'),'1')
  self.assertEqual(sql('select public.dispatch_preferred_task_alerts()',role='service_role'),'0')
  self.assertEqual(sql("select count(*) from public.notifications where kind='preferred_task'",U),'1')
  self.assertEqual(sql("select count(*) from public.notifications where kind='preferred_task'",X),'0')
  sql(f"update public.campaigns set \"createdAt\"=now()-interval '2 minutes' where id='{C3}'",role='owner')
  sql('select public.set_user_notification_preferences(false,true,true)',U)
  self.assertEqual(sql('select public.dispatch_preferred_task_alerts()',role='service_role'),'1')
  self.assertEqual(sql(f"select count(*) from public.notifications where user_id='{U}' and kind='preferred_task' and not show_in_app and not deliver_push",role='owner'),'1')
 def test_03z_blocking_and_concurrent_dispatch(self):
  sql("select public.set_user_notification_preferences(true,true,true)",U)
  sql(f"insert into public.user_access(user_id,blocked) values('{U}',true) on conflict(user_id) do update set blocked=true",role='owner')
  c4='d1000000-0000-4000-8000-000000000004'
  sql(f"insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining,\"createdAt\") values('{c4}','{O}','like','https://instagram.com/p/FOUR/','active',1,1,now()-interval '2 minutes')",role='owner')
  self.assertEqual(sql('select public.dispatch_preferred_task_alerts()',role='service_role'),'0')
  sql(f"update public.user_access set blocked=false where user_id='{U}'",role='owner')
  def dispatch(_):return int(sql('select public.dispatch_preferred_task_alerts()',role='service_role'))
  with ThreadPoolExecutor(max_workers=2) as pool: result=list(pool.map(dispatch,[0,1]))
  self.assertEqual(sorted(result),[0,1])
  self.assertEqual(sql(f"select count(*) from growth_internal.preferred_task_alert_log where user_id='{U}' and campaign_id='{c4}'",role='owner'),'1')
  c5='d1000000-0000-4000-8000-000000000005'
  sql(f"insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining,\"createdAt\") values('{c5}','{O}','like','https://instagram.com/p/FIVE/','active',1,1,now()-interval '2 minutes')",role='owner')
  sql("update public.action_controls set enabled=false where action_type='like'",role='owner')
  self.assertEqual(sql('select public.dispatch_preferred_task_alerts()',role='service_role'),'0')
  sql("update public.action_controls set enabled=true where action_type='like'",role='owner')
  self.assertEqual(sql('select public.dispatch_preferred_task_alerts()',role='service_role'),'1')

 def test_04_monthly_spending_and_controls(self):
  sql(f"insert into public.coin_ledger(user_id,amount,reason) values('{U}',-4,'campaign'),('{U}',-3,'transfer_sent'),('{X}',-40,'campaign')",role='owner')
  result=json.loads(sql('select public.monthly_spending_insights()',U))
  self.assertEqual((result['campaign'],result['transfer']),(4,3))
  self.assertEqual(result,json.loads(sql("set timezone='America/New_York'; select public.monthly_spending_insights()",U)))
  keys=['task_instructions','screenshot_editing','submission_waiting','report_tracking','notification_filters','saved_task_notes','preferred_task_alerts','spending_insights']
  sql("select public.admin_set_user_feature('task_instructions',false)",V,fail=True)
  for k in keys:sql(f"select public.admin_set_user_feature('{k}',false)",A)
  sql('select public.monthly_spending_insights()',U,fail=True)
  sql('select public.user_campaign_reports()',U,fail=True)
  self.assertEqual(sql('select public.dispatch_preferred_task_alerts()',role='service_role'),'0')
  sql(f"select public.set_campaign_instructions('{C}','no')",O,fail=True)
  for k in keys:sql(f"select public.admin_set_user_feature('{k}',true)",A)
 def test_05_deleted_account_archive(self):
  sql(f"select public.set_task_saved('{C2}',true)",X)
  sql(f"select public.set_saved_task_note('{C2}','keep in archive')",X)
  sql(f"delete from auth.users where id='{X}'",role='owner')
  self.assertEqual(sql(f"select snapshot ? 'growth_internal.saved_task_notes' from growth_internal.deleted_account_archives where user_id='{X}'",role='owner'),'f')
  self.assertEqual(sql(f"select jsonb_array_length(snapshot->'growth_internal.preferred_task_categories') from growth_internal.deleted_account_archives where user_id='{X}'",role='owner'),'1')
 def test_06_owner_deletion_does_not_archive_others_notes(self):
  sql(f"select public.set_task_saved('{C2}',true)",U)
  sql(f"select public.set_saved_task_note('{C2}','private participant note')",U)
  sql(f"delete from auth.users where id='{O}'",role='owner')
  self.assertEqual(sql(f"select snapshot ? 'growth_internal.saved_task_notes' from growth_internal.deleted_account_archives where user_id='{O}'",role='owner'),'f')
  self.assertEqual(sql(f"select count(*) from growth_internal.saved_task_notes where user_id='{U}' and campaign_id='{C2}'",role='owner'),'0')
if __name__=='__main__':unittest.main(verbosity=2)
