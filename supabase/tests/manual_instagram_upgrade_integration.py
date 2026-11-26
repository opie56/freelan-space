"""Historical duplicate usernames survive migration and cannot be newly claimed."""
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]


def sql(query):
    return subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB,
                           '-c', query], capture_output=True, text=True)


class UpgradeTest(unittest.TestCase):
    def test_legacy_duplicates_preserved(self):
        self.assertEqual(sql("select count(*) from public.instagram_accounts where lower(username)='legacy'").stdout.strip(), '2')
        result = sql("set role authenticated; select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000001',false); select public.add_instagram_account('@LEGACY')")
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
