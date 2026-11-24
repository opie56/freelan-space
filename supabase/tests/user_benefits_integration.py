"""User benefits authorization, accounting, preferences and reminder checks on a disposable database."""
from admin_test_support import enroll_test_admins, test_claims
import json, subprocess, sys, unittest
DB=sys.argv[1]; sys.argv=sys.argv[:1]
O='90000000-0000-4000-8000-000000000001'; U='90000000-0000-4000-8000-000000000002'; X='90000000-0000-4000-8000-000000000003'; A='90000000-0000-4000-8000-000000000004'; V='90000000-0000-4000-8000-000000000005'; C='91000000-0000-4000-8000-000000000001'; S='92000000-0000-4000-8000-000000000001'; T='92000000-0000-4000-8000-000000000002'
def sql(q, uid=None, role='authenticated', fail=False):
    prefix=(f"set role {role}; select set_config('request.jwt.claim.sub','{uid}',false); " if uid else (f'set role {role}; ' if role!='owner' else ''))
    p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+q],capture_output=True,text=True)
    if fail:
        if p.returncode==0: raise AssertionError('Unexpected success: '+q)
    elif p.returncode: raise AssertionError(p.stderr)
    return (p.stdout.strip().splitlines() or [''])[-1]
class UserBenefits(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql(f"""insert into auth.users(id,email) values ('{O}','o@example.test'),('{U}','u@example.test'),('{X}','x@example.test'),('{A}','a@example.test'),('{V}','v@example.test');
        insert into public.admin_members(user_id,role) values ('{A}','editor'),('{V}','viewer');
        insert into public.wallets(id,balance) values('{O}',20),('{U}',20),('{X}',20);
        insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining,reward_per_task) values('{C}','{O}','like','https://instagram.com/p/TEST/','active',2,2,1);
        insert into public.campaign_claims(campaign_id,user_id,submission_id,status,instagram_handle,created_at) values('{C}','{U}','{S}','rejected','sample',now()-interval '2 days'),('{C}','{X}','{T}','pending','sample',now()-interval '2 days');
        insert into public.coin_ledger(user_id,amount,reason) values('{U}',5,'task'),('{U}',-2,'campaign'),('{X}',42,'welcome');""",role='owner')
        enroll_test_admins(DB)
    def test_01_admin_controls_and_summary(self):
        settings=json.loads(sql('select public.user_feature_settings()',U)); self.assertTrue(all(settings.values()))
        sql("select public.admin_set_user_feature('coin_summary',false)",U,fail=True)
        sql("select public.admin_set_user_feature('coin_summary',false)",V,fail=True)
        sql("select public.admin_set_user_feature('coin_summary',false)",A)
        sql('select public.user_weekly_coin_summary()',U,fail=True)
        sql("select public.admin_set_user_feature('coin_summary',true)",A)
        summary=json.loads(sql('select public.user_weekly_coin_summary()',U))
        self.assertEqual((summary['earned'],summary['spent']),(5,2))
        sql(f"select public.user_campaign_insights('{C}')",U,fail=True)
        data=json.loads(sql(f"select public.user_campaign_insights('{C}')",O)); self.assertEqual(data['rejected'],1)
    def test_02_appeal_isolation_and_unique(self):
        sql("select public.admin_set_user_feature('submission_appeals',false)",A)
        sql(f"select public.appeal_submission('{S}','disabled')",U,fail=True)
        sql("select public.admin_set_user_feature('submission_appeals',true)",A)
        sql(f"select public.appeal_submission('{S}','wrong user')",X,fail=True)
        ticket=sql(f"select public.appeal_submission('{S}','Please review')",U)
        self.assertEqual(sql(f"select count(*) from public.support_my_tickets() where id='{ticket}'",U),'1')
        self.assertEqual(sql(f"select count(*) from public.support_my_tickets() where id='{ticket}'",X),'0')
        sql(f"select public.appeal_submission('{S}','again')",U,fail=True)
        sql(f"select public.appeal_submission('{T}','pending')",X,fail=True)
    def test_03_preferences_and_reminders(self):
        sql('select public.set_user_notification_preferences(false,true,false)',O)
        sql(f"insert into public.notifications(user_id,kind) values('{O}','approved')",role='owner')
        self.assertEqual(sql(f"select count(*) from public.notifications where user_id='{O}' and kind='approved' and not show_in_app and not deliver_push",role='owner'),'1')
        sql('select public.send_pending_review_reminders()',O,fail=True)
        self.assertEqual(sql('select public.send_pending_review_reminders()',role='service_role'),'1')
        self.assertEqual(sql('select public.send_pending_review_reminders()',role='service_role'),'0')
        self.assertEqual(sql(f"select count(*) from public.notifications where user_id='{O}' and kind='review_reminder' and not show_in_app and not deliver_push",role='owner'),'1')
        sql(f"update public.notifications set created_at=now()-interval '73 hours' where user_id='{O}' and kind='approved'",role='owner')
        sql('select growth_internal.purge_expired_user_notifications()',role='owner')
        self.assertEqual(sql(f"select count(*) from public.notifications where user_id='{O}' and kind='approved'",role='owner'),'0')
        sql("select public.admin_set_user_feature('review_reminders',false)",A)
        self.assertEqual(sql('select public.send_pending_review_reminders()',role='service_role'),'0')
if __name__=='__main__': unittest.main(verbosity=2)
