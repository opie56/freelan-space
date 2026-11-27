import base64
import io
import unittest

from PIL import Image, ImageDraw, ImageFont
from server import compare, decode_photo, recognize


class OcrTest(unittest.TestCase):
    def test_document_name_not_a_substring_or_fathers_name(self):
        front = "INCOME TAX DEPARTMENT\nName: Taylor Example\nFather's Name: Sam Example"
        back = "If this card is lost please return the card"
        self.assertEqual(compare("pan", "Taylor Example", front, back)["status"], "match")
        self.assertEqual(compare("pan", "Taylor", front, back)["status"], "mismatch")
        self.assertEqual(compare("pan", "Sam Example", front, back)["status"], "mismatch")
        self.assertEqual(compare("pan", "Taylor Example", front, front)["status"], "unreadable")

    def test_document_specific_layouts(self):
        for kind, front, back in [
            ("aadhaar", "Aadhaar\nTaylor Example\nDOB: 01/01/2000", "Address: sample"),
            ("voter_id", "ELECTION COMMISSION OF INDIA\nName:\nTaylor Example", "Address: sample"),
            ("driving_licence", "DRIVING LICENCE\nName: Taylor Example", "Licensing Authority"),
            ("passport", "REPUBLIC OF INDIA\nSurname\nEXAMPLE\nGiven Name(s)\nTAYLOR", "File No 0001"),
            ("pan", "INCOME TAX DEPARTMENT\nName: Taylor Example", "Return the card"),
        ]:
            with self.subTest(kind=kind):
                self.assertEqual(compare(kind, "Taylor Example", front, back)["status"], "match")

    def test_tesseract_reads_synthetic_front_and_back(self):
        def sample(lines):
            image = Image.new("RGB", (960, 440), "white")
            draw = ImageDraw.Draw(image)
            font = ImageFont.truetype("DejaVuSans.ttf", 42)
            for row, text in enumerate(lines):
                draw.text((30, 38 + row * 92), text, fill="black", font=font)
            file = io.BytesIO()
            image.save(file, format="PNG")
            return recognize(decode_photo(base64.b64encode(file.getvalue()).decode(), "image/png"))

        front = sample(["INCOME TAX DEPARTMENT", "Name: Taylor Example", "Date of Birth: 01-01-2000"])
        back = sample(["If this card is lost", "Return the card"])
        self.assertEqual(compare("pan", "Taylor Example", front, back)["status"], "match")
        self.assertEqual(compare("pan", "Another Name", front, back)["status"], "mismatch")


if __name__ == "__main__":
    unittest.main()
