"""Real-name proof privacy, admin authorization and name-bound badge."""
import json
import base64
import zlib
import subprocess
import sys
import unittest
from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
sys.argv = sys.argv[:1]
EDITOR, VIEWER, USER, OTHER, AUTO = [f'98000000-0000-4000-8000-{n:012d}' for n in range(1, 6)]
PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='

def png_for_color(rgb):
    def chunk(tag, data):
        return len(data).to_bytes(4, 'big') + tag + data + zlib.crc32(tag + data).to_bytes(4, 'big')
    ihdr = (1).to_bytes(4, 'big') * 2 + bytes([8, 2, 0, 0, 0])
    return base64.b64encode(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr)
                            + chunk(b'IDAT', zlib.compress(b'\0' + rgb)) + chunk(b'IEND', b'')).decode()


BACK = png_for_color(b'\0\x33\x99')


def scan(user, match, back=BACK):
    return (f"select public.submit_scanned_real_name('{user}','Alice Example','aadhaar',"
            f"'image/png','{PNG}','image/png','{back}',{str(match).lower()})")

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
        sql('insert into auth.users(id,email,raw_user_meta_data) values '+','.join(f"('{u}','v{i}@example.test','{{\"full_name\":\"Alice Example\"}}')" for i,u in enumerate((EDITOR,VIEWER,USER,OTHER,AUTO))))
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
        sql(f"update auth.users set raw_user_meta_data='{{\"full_name\":\"Other\"}}' where id='{USER}'",fails=True)
        sql(f"update auth.users set raw_user_meta_data=raw_user_meta_data || '{{\"locale\":\"ml\"}}' where id='{USER}'")
        self.assertEqual(json.loads(sql('select public.real_name_verification_status()',USER))['verified_name'],'Bob')
        sql(submit,USER,fails=True)
        sql(f"delete from auth.users where id='{USER}'")
        self.assertEqual(sql(f"select count(*) from growth_internal.real_name_verifications where user_id='{USER}'"),'0')

        # App roles cannot attest to an OCR match or read either side of the proof.
        sql(scan(OTHER, True),OTHER,fails=True)
        sql(f"select public.allow_real_name_scan('{OTHER}')",OTHER,fails=True)
        sql(f"set role service_role; {scan(OTHER, True, PNG)}",fails=True)
        sql(f"insert into public.user_access(user_id, blocked) values ('{OTHER}', true)")
        sql(f"set role service_role; {scan(OTHER, True)}",fails=True)
        sql(f"delete from public.user_access where user_id='{OTHER}'")
        for _ in range(8):
            self.assertEqual(sql(f"set role service_role; select public.allow_real_name_scan('{OTHER}')"),'t')
        self.assertEqual(sql(f"set role service_role; select public.allow_real_name_scan('{OTHER}')"),'f')
        self.assertEqual(json.loads(sql(f"set role service_role; {scan(OTHER, False)}"))['status'], 'pending')
        manual = sql(f"select request_id from growth_internal.real_name_verifications where user_id='{OTHER}'")
        sql(f"select public.admin_real_name_proofs('{manual}')",OTHER,fails=True)
        sql(f"select public.admin_real_name_proofs('{manual}')",VIEWER,{'aal':'aal1'},fails=True)
        proofs = json.loads(sql(f"select public.admin_real_name_proofs('{manual}')",VIEWER))
        self.assertEqual(proofs, {'document_type': 'aadhaar', 'front': PNG, 'back': BACK})
        sql(f"select public.admin_decide_real_name('{manual}',false,'Retake the back photo.')",VIEWER,fails=True)
        sql(f"select public.admin_decide_real_name('{manual}',true)",EDITOR,fails=True)
        sql(f"select public.admin_decide_real_name('{manual}',false,'   ')",EDITOR,fails=True)
        sql(f"select public.admin_decide_real_name('{manual}',false,'Retake the back photo.')",EDITOR)
        rejected = json.loads(sql('select public.real_name_verification_status()',OTHER))
        self.assertEqual((rejected['status'],rejected['rejection_reason']), ('rejected','Retake the back photo.'))
        self.assertEqual(sql(f"select proof_data is null and back_data is null from growth_internal.real_name_verifications where user_id='{OTHER}'"),'t')

        result = json.loads(sql(f"set role service_role; {scan(AUTO, True)}"))
        self.assertEqual(result, {'status': 'processing', 'seconds_remaining': 10})
        pending = json.loads(sql('select public.real_name_verification_status()',AUTO))
        self.assertEqual(pending['status'], 'pending')
        self.assertGreater(pending['seconds_remaining'],0)
        sql(f"update auth.users set raw_user_meta_data='{{\"full_name\":\"Other\"}}' where id='{AUTO}'",fails=True)
        sql(f"update growth_internal.real_name_verifications set auto_verify_at=now()-interval '1 second' where user_id='{AUTO}'")
        sql('select growth_internal.finish_due_real_name_scans()')
        approved = json.loads(sql('select public.real_name_verification_status()',AUTO))
        self.assertEqual((approved['status'],approved['verified_name']),('approved','Alice Example'))
        self.assertEqual(sql(f"select proof_data is null and back_data is null from growth_internal.real_name_verifications where user_id='{AUTO}'"),'t')

        # Legacy apps can retry a previously rejected two-sided request.
        sql(submit,OTHER)
        self.assertEqual(json.loads(sql('select public.real_name_verification_status()',OTHER))['status'],'pending')
        self.assertEqual(sql(f"select document_type is null and rejection_reason is null from growth_internal.real_name_verifications where user_id='{OTHER}'"),'t')

        # A historic approval already mismatched at rollout can still be submitted again.
        sql(f"update growth_internal.real_name_verifications set submitted_name='Old Name' where user_id='{AUTO}'")
        self.assertEqual(json.loads(sql('select public.real_name_verification_status()',AUTO))['status'],'name_changed')
        self.assertEqual(json.loads(sql(f"set role service_role; {scan(AUTO, False)}"))['status'],'pending')

if __name__ == '__main__': unittest.main()
