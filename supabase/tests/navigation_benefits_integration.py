"""Disposable database: pause, coupon, quiet-hour and session isolation."""
from admin_test_support import enroll_test_admins, test_claims
from concurrent.futures import ThreadPoolExecutor
import json,subprocess,sys,unittest
DB=sys.argv[1];sys.argv=sys.argv[:1]
O='b0000000-0000-4000-8000-000000000001';U='b0000000-0000-4000-8000-000000000002';X='b0000000-0000-4000-8000-000000000003';A='b0000000-0000-4000-8000-000000000004';V='b0000000-0000-4000-8000-000000000005';C='b1000000-0000-4000-8000-000000000001';S='b2000000-0000-4000-8000-000000000001';T='b2000000-0000-4000-8000-000000000002';R='b2000000-0000-4000-8000-000000000003'
def sql(q,uid=None,role='authenticated',fail=False,session=None):
 prefix=f"set role {role}; select set_config('request.jwt.claim.sub','{uid}',false); " if uid else (f'set role {role}; ' if role!='owner' else '')
 if session: prefix+=f"select set_config('request.jwt.claims','{{\"session_id\":\"{session}\",\"aal\":\"aal2\"}}',false); "
 p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+q],capture_output=True,text=True)
 if fail:
  if p.returncode==0: raise AssertionError('Unexpected success: '+q)
 elif p.returncode: raise AssertionError(p.stderr)
 return (p.stdout.strip().splitlines() or [''])[-1]
class NavigationBenefits(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  sql(f"""insert into auth.users(id,email) values ('{O}','o@example.test'),('{U}','u@example.test'),('{X}','x@example.test'),('{A}','a@example.test'),('{V}','v@example.test');
  insert into public.admin_members(user_id,role) values('{A}','editor'),('{V}','viewer');
  insert into public.wallets(id,balance) values('{O}',10),('{U}',10),('{X}',10);
  insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining,\"createdAt\") values('{C}','{O}','like','https://instagram.com/p/TEST/','active',3,3,now()-interval '2 minutes');
  insert into auth.sessions(id,user_id,user_agent) values('{S}','{U}','device one'),('{T}','{U}','device two'),('{R}','{X}','other');
  insert into auth.refresh_tokens(session_id) values('{T}');
  insert into growth_internal.release_pins(user_id,pin_hash) values('{U}',extensions.crypt('1234',extensions.gen_salt('bf',12)));""",role='owner')
  enroll_test_admins(DB)
 def test_01_pause_permissions_and_resume(self):
  sql(f"select public.set_campaign_paused('{C}',true)",U,fail=True)
  sql(f"select public.set_campaign_paused('{C}',true)",O)
  self.assertEqual(sql(f"select paused from public.campaigns where id='{C}'",O),'t')
  sql(f"select public.submit_claim('{C}','sample','image/png','abc')",U,fail=True)
  sql("select public.admin_set_user_feature('campaign_pause',false)",A)
  sql(f"select public.set_campaign_paused('{C}',false)",O)
  self.assertEqual(sql(f"select paused from public.campaigns where id='{C}'",O),'f')
  sql(f"select public.set_campaign_paused('{C}',true)",O,fail=True)
 def test_02_coupon_cap_and_access(self):
  sql("select public.admin_create_coupon('TEST123',3,1,now()+interval '1 day')",V,fail=True)
  sql("select public.admin_create_coupon('TEST123',3,1,now()+interval '1 day')",A)
  def attempt(user):return json.loads(sql("select public.redeem_bonus_coupon('TEST123')",user))['status']
  with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(attempt,[U,X]))
  self.assertEqual(sorted(results),['ok','unavailable'])
  self.assertEqual(sql("select sum(amount) from public.coin_ledger where reason='coupon_bonus'",role='owner'),'3')
  sql('select * from growth_internal.bonus_coupons',U,fail=True)
 def test_03_quiet_hours_and_queue(self):
  sql('select public.set_user_quiet_hours(1320,420,330)',U)
  self.assertEqual(sql(f"select growth_internal.user_is_quiet('{U}','2026-11-24 18:00+00')",role='owner'),'t')
  self.assertEqual(sql(f"select growth_internal.user_is_quiet('{U}','2026-11-24 07:00+00')",role='owner'),'f')
  self.assertEqual(sql('select public.user_quiet_hours() is null',X),'t')
  sql('select public.set_user_quiet_hours(0,0,0)',U,fail=True)
  # Exercise the actual v3 worker claim path with one quiet and one eligible user.
  sql("select public.register_push_token('quiet-token-12345678901234567890')",U)
  sql("select public.register_push_token('awake-token-12345678901234567890')",X)
  sql(f"insert into public.notifications(user_id,kind) values('{U}','approved'),('{X}','approved')",role='owner')
  sql(f"update growth_internal.quiet_hours set start_minute=((extract(hour from now() at time zone 'UTC')::int*60+extract(minute from now() at time zone 'UTC')::int+1439)%1440),end_minute=((extract(hour from now() at time zone 'UTC')::int*60+extract(minute from now() at time zone 'UTC')::int+60)%1440),offset_minute=0 where user_id='{U}'",role='owner')
  self.assertEqual(sql('select count(*) from public.claim_push_jobs_v3(50)',role='service_role'),'1')
  self.assertEqual(sql(f"select count(*) from growth_internal.push_jobs j join growth_internal.push_tokens t on j.token_id=t.id where t.user_id='{U}' and j.status='pending'",role='owner'),'1')
  sql('select public.set_user_quiet_hours(null,null,null)',U)
  self.assertEqual(sql('select count(*) from public.claim_push_jobs_v3(50)',role='service_role'),'1')
 def test_04_session_isolation_and_pin(self):
  sql("select public.register_push_token('current-token-123456789012345678')",U,session=S)
  sql("select public.register_push_token('other-token-12345678901234567890')",U,session=T)
  self.assertEqual(sql('select count(*) from public.user_device_sessions()',U,session=S),'2')
  self.assertEqual(sql(f"select public.revoke_device_session('{R}','1234')",U,session=S),'unavailable')
  self.assertEqual(sql(f"select public.revoke_device_session('{T}','4321')",U,session=S),'invalid_pin')
  self.assertEqual(sql(f"select public.revoke_device_session('{T}','1234')",U,session=S),'ok')
  self.assertEqual(sql(f"select count(*) from auth.refresh_tokens where session_id='{T}'",role='owner'),'0')
  self.assertEqual(sql(f"select count(*) from growth_internal.push_tokens where user_id='{U}' and session_id='{T}'",role='owner'),'0')
  self.assertEqual(sql(f"select count(*) from growth_internal.push_tokens where user_id='{U}' and session_id='{S}'",role='owner'),'1')
  sql("select public.register_push_token('other-token-12345678901234567890')",U,session=T,fail=True)
  sql(f"select public.revoke_device_session('{S}','1234')",U,session=S,fail=True)
if __name__=='__main__':unittest.main(verbosity=2)
