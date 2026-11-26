"""Real-name proof privacy, admin authorization and name-bound badge."""
import json
import subprocess
import sys
import unittest
from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
sys.argv = sys.argv[:1]
EDITOR, VIEWER, USER, OTHER = [f'98000000-0000-4000-8000-{n:012d}' for n in range(1, 5)]
PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='

def sql(query, user=None, claims=None, fails=False):
    prefix = '' if not user else (f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
        f"select set_config('request.jwt.claims','{json.dumps(claims or {})}',false); ")
    result = subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+query],capture_output=True,text=True)
    if fails:
        if result.returncode == 0: raise AssertionError('Unexpected success')
    elif result.returncode: raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

class VerificationTests(unittest.TestCase):
    def test_flow(self):
        sql('insert into auth.users(id,email,raw_user_meta_data) values '+','.join(f"('{u}','v{i}@example.test','{{\"full_name\":\"Alice Example\"}}')" for i,u in enumerate((EDITOR,VIEWER,USER,OTHER))))
        sql(f"insert into public.admin_members(user_id,role) values ('{EDITOR}','editor'),('{VIEWER}','viewer')")
        enroll_test_admins(DB)
        submit = f"select public.submit_real_name_verification('image/png','{PNG}')"
        sql("select public.submit_real_name_verification('image/png','bad')",USER,fails=True)
        sql(submit,USER)
        sql(submit,USER,fails=True)
        request = sql(f"select request_id from growth_internal.real_name_verifications where user_id='{USER}'")
        self.assertEqual(json.loads(sql('select public.real_name_verification_status()',USER))['status'],'pending')
        sql('select * from growth_internal.real_name_verifications',USER,fails=True)
        sql('select * from public.admin_real_name_requests()',OTHER,fails=True)
        sql(f"select public.admin_real_name_proof('{request}')",OTHER,fails=True)
        sql(f"select public.admin_real_name_proof('{request}')",VIEWER,{'aal':'aal1'},fails=True)
        self.assertEqual(sql(f"select public.admin_real_name_proof('{request}')",VIEWER),PNG)
        sql(f"select public.admin_decide_real_name('{request}',true)",VIEWER,fails=True)
        sql(f"update auth.users set raw_user_meta_data='{{\"full_name\":\"Bob\"}}' where id='{USER}'")
        sql(f"select public.admin_decide_real_name('{request}',true)",EDITOR,fails=True)
        sql(f"select public.admin_decide_real_name('{request}',false)",EDITOR)
        self.assertEqual(sql(f"select proof_data is null from growth_internal.real_name_verifications where user_id='{USER}'"),'t')
        self.assertEqual(json.loads(sql('select public.real_name_verification_status()',USER))['status'],'rejected')
        sql(submit,USER)
        next_request = sql(f"select request_id from growth_internal.real_name_verifications where user_id='{USER}'")
        self.assertNotEqual(request,next_request)
        sql(f"select public.admin_decide_real_name('{request}',true)",EDITOR,fails=True)
        sql(f"select public.admin_decide_real_name('{next_request}',true)",EDITOR)
        state = json.loads(sql('select public.real_name_verification_status()',USER))
        self.assertEqual((state['status'],state['verified_name']),('approved','Bob'))
        self.assertEqual(sql(f"select proof_data is null from growth_internal.real_name_verifications where user_id='{USER}'"),'t')
        sql(f"update auth.users set raw_user_meta_data='{{\"full_name\":\"Other\"}}' where id='{USER}'")
        self.assertEqual(json.loads(sql('select public.real_name_verification_status()',USER))['status'],'name_changed')
        sql(submit,USER)
        sql(f"delete from auth.users where id='{USER}'")
        self.assertEqual(sql(f"select count(*) from growth_internal.real_name_verifications where user_id='{USER}'"),'0')

if __name__ == '__main__': unittest.main()
