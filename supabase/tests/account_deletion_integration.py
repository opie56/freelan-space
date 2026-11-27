"""Synthetic, disposable DB only; no real accounts."""
import sys,unittest
from pin_reauthentication_integration import sql,issue,USER,OTHER

class Deletion(unittest.TestCase):
 def setUp(self):
  sql(f"delete from auth.users where id in ('{USER}','{OTHER}'); insert into auth.users(id) values ('{USER}'),('{OTHER}')")
  for user in (USER,OTHER): sql('select public.initialize_wallet()',user)
 def delete(self,nonce='123456',user=USER):
  return sql(f"select public.delete_my_account('{nonce}')",user)
 def test_delete_cascades_preserves_receipt_and_other_user(self):
  sql(f"insert into public.coin_purchase_orders(user_id,plan_id,coins,amount_paise) values('{USER}','starter',100,4900)")
  issue(); self.assertEqual(self.delete(),'ok')
  self.assertEqual(sql(f"select count(*) from auth.users where id='{USER}'"),'0')
  self.assertEqual(sql(f"select count(*) from public.wallets where id='{USER}'"),'0')
  self.assertEqual(sql('select count(*) from public.coin_purchase_orders where user_id is null'),'1')
  self.assertEqual(sql(f"select count(*) from auth.users where id='{OTHER}'"),'1')
  sql("select public.delete_my_account('123456')",USER,fails=True)
 def verify(self,nonce='123456',user=USER):
  return sql(f"select public.verify_account_deletion_code('{nonce}')",user)
 def test_verification_does_not_delete_and_final_call_rechecks(self):
  issue()
  self.assertEqual(self.verify(user=OTHER),'otp_required')
  self.assertEqual(self.verify(),'ok')
  self.assertEqual(sql(f"select count(*) from auth.users where id='{USER}'"),'1')
  issue(age="interval '6 minutes'")
  self.assertEqual(self.delete(),'otp_required')
  issue()
  for _ in range(5): self.assertEqual(self.verify('999999'),'otp_required')
  self.assertEqual(self.delete(),'otp_required')
  issue()
  self.assertEqual(self.verify(),'ok')
  self.assertEqual(self.delete(),'ok')
  sql("set role anon; select public.verify_account_deletion_code('123456')",fails=True)
 def test_otp_scope_expiry_lockout_and_admin(self):
  self.assertEqual(self.delete(),'otp_required'); issue()
  self.assertEqual(self.delete(user=OTHER),'otp_required')
  for _ in range(5): self.assertEqual(self.delete('999999'),'otp_required')
  self.assertEqual(self.delete(),'otp_required')
  issue(age="interval '6 minutes'"); self.assertEqual(self.delete(),'otp_required')
  issue(); sql(f"insert into public.admin_members(user_id) values('{USER}')")
  self.assertEqual(self.delete(),'admin_account')
  sql(f"delete from public.admin_members where user_id='{USER}'")
  sql("set role anon; select public.delete_my_account('123456')",fails=True)

if __name__=='__main__': unittest.main(verbosity=2)
