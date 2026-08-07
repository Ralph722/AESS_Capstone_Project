#!/usr/bin/env python3
"""Generate CHED-GTS-v3.1.0-fillable.pdf from the official CHED GTS structure.

Leaves CHED-GTS-v3.0.0-fillable.pdf untouched. Field names extend the app's
existing camelCase / group__slug convention for Syncfusion export.

Layout rules:
- Header area is intentionally blank (campus export, not an official CHED letterhead).
- AcroForm widgets are always placed *below* the current cursor (never overlapping labels).
- Section E (alumni referrals) is omitted.
"""

from __future__ import annotations

from pathlib import Path

from reportlab.lib.colors import Color, black, white
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

OUT = (
    Path(__file__).resolve().parents[2]
    / "assets"
    / "ched_gts"
    / "CHED-GTS-v3.1.0-fillable.pdf"
)

PAGE_W, PAGE_H = A4
MARGIN_L = 40
MARGIN_R = 40
MARGIN_T = 36
MARGIN_B = 40
CONTENT_W = PAGE_W - MARGIN_L - MARGIN_R

NAVY = Color(0.05, 0.15, 0.35)
LIGHT = Color(0.93, 0.95, 0.98)
LINE = Color(0.55, 0.55, 0.55)

COURSE_REASON_SLUGS = [
    ("high-grades", "High grades in the course or subject area(s) related to the course"),
    ("hs-grades", "Good grades in high school"),
    ("parents", "Influence of parents or relatives"),
    ("peers", "Peer Influence"),
    ("role-model", "Inspired by a role model"),
    ("passion", "Strong passion for the profession"),
    ("employment-prospect", "Prospect for immediate employment"),
    ("prestige", "Status or prestige of the profession"),
    ("availability", "Availability of course offering in chosen institution"),
    ("career-advancement", "Prospect of career advancement"),
    ("affordability", "Affordable for the family"),
    ("compensation", "Prospect of attractive compensation"),
    ("abroad", "Opportunity for employment abroad"),
    ("no-choice", "No particular choice or no better idea"),
]

BUSINESS_LINES = [
    "Agriculture, Hunting and Forestry",
    "Fishing",
    "Mining and Quarrying",
    "Manufacturing",
    "Electricity, Gas and Water Supply",
    "Construction",
    "Wholesale and Retail Trade, repair of motor vehicles, motorcycles and personal and household goods",
    "Hotels and Restaurants",
    "Transport Storage and Communication",
    "Financial Intermediation",
    "Real Estate, Renting and Business Activities",
    "Public Administration and Defense; Compulsory Social Security",
    "Education",
    "Health and Social Work",
    "Other Community, Social and Personal Service Activities",
    "Private Households with Employed Persons",
    "Extra-territorial Organizations and Bodies",
]

REGIONS = [
    "Region 1", "Region 2", "Region 3", "Region 4", "Region 5", "Region 6",
    "Region 7", "Region 8", "Region 9", "Region 10", "Region 11", "Region 12",
    "NCR", "CAR", "ARMM", "CARAGA",
]


def _truncate(c: canvas.Canvas, text: str, max_w: float, size: float) -> str:
    if c.stringWidth(text, "Helvetica", size) <= max_w:
        return text
    while text and c.stringWidth(text + "...", "Helvetica", size) > max_w:
        text = text[:-1]
    return text + "..."


class FormBuilder:
    def __init__(self, path: Path):
        self.path = path
        self.c = canvas.Canvas(str(path), pagesize=A4)
        self.page = 1
        self.field_names: list[str] = []
        self.y = PAGE_H - MARGIN_T

    def new_page(self):
        self._footer()
        self.c.showPage()
        self.page += 1
        self.y = PAGE_H - MARGIN_T
        # Header intentionally blank.

    def _footer(self):
        self.c.setFont("Helvetica", 7)
        self.c.setFillColor(Color(0.45, 0.45, 0.45))
        self.c.drawRightString(PAGE_W - MARGIN_R, 22, f"Page {self.page}")
        self.c.setFillColor(black)

    def ensure(self, need: float):
        if self.y - need < MARGIN_B:
            self.new_page()

    def gap(self, h: float = 8):
        self.y -= h

    def title(self, text: str, size: int = 12):
        self.ensure(size + 14)
        self.c.setFont("Helvetica-Bold", size)
        self.c.setFillColor(NAVY)
        self.c.drawCentredString(PAGE_W / 2, self.y - size, text)
        self.c.setFillColor(black)
        self.y -= size + 12

    def section(self, text: str):
        """Section bar with clear padding above and below."""
        bar_h = 18
        self.ensure(bar_h + 22)
        self.y -= 10
        bar_bottom = self.y - bar_h
        self.c.setFillColor(LIGHT)
        self.c.rect(MARGIN_L, bar_bottom, CONTENT_W, bar_h, fill=1, stroke=0)
        self.c.setFillColor(NAVY)
        self.c.setFont("Helvetica-Bold", 10)
        self.c.drawString(MARGIN_L + 6, bar_bottom + 5, text)
        self.c.setFillColor(black)
        self.y = bar_bottom - 12

    def label(self, text: str, size: int = 8, bold: bool = False):
        self.ensure(size + 16)
        font = "Helvetica-Bold" if bold else "Helvetica"
        self.c.setFont(font, size)
        max_w = CONTENT_W
        words = text.split()
        line = ""
        for w in words:
            trial = (line + " " + w).strip()
            if self.c.stringWidth(trial, font, size) > max_w and line:
                self.c.drawString(MARGIN_L, self.y - size, line)
                self.y -= size + 3
                line = w
            else:
                line = trial
        if line:
            self.c.drawString(MARGIN_L, self.y - size, line)
            self.y -= size + 5

    def note(self, text: str):
        self.ensure(14)
        self.c.setFont("Helvetica-Oblique", 7)
        self.c.setFillColor(Color(0.3, 0.3, 0.3))
        self.c.drawString(MARGIN_L, self.y - 7, text)
        self.c.setFillColor(black)
        self.y -= 12

    def _track(self, name: str):
        if name not in self.field_names:
            self.field_names.append(name)

    def text(
        self,
        name: str,
        x: float,
        y: float,
        w: float,
        h: float,
        *,
        multiline: bool = False,
        font_size: float = 8,
    ):
        self._track(name)
        self.c.acroForm.textfield(
            name=name,
            tooltip=name,
            x=x,
            y=y,
            width=w,
            height=h,
            borderWidth=0.6,
            borderColor=LINE,
            fillColor=Color(0.98, 0.99, 1.0),
            textColor=black,
            forceBorder=True,
            fontSize=font_size,
            fieldFlags="multiline" if multiline else "",
        )

    def text_row(
        self,
        name: str,
        h: float = 14,
        *,
        multiline: bool = False,
        indent: float = 0,
        width: float | None = None,
        x: float | None = None,
    ):
        """Place a text field fully below the cursor, then advance past it."""
        self.ensure(h + 10)
        self.y -= 2
        field_y = self.y - h
        self.text(
            name,
            x if x is not None else MARGIN_L + indent,
            field_y,
            width if width is not None else CONTENT_W - indent,
            h,
            multiline=multiline,
        )
        self.y = field_y - 8

    def labeled_line(self, num_label: str, field: str, h: float = 14):
        self.label(num_label, bold=True)
        self.text_row(field, h=h)

    def checkbox(self, name: str, x: float, y: float, size: float = 9):
        self._track(name)
        self.c.acroForm.checkbox(
            name=name,
            tooltip=name,
            x=x,
            y=y,
            size=size,
            buttonStyle="check",
            borderColor=LINE,
            fillColor=white,
            textColor=black,
            checked=False,
        )

    def radio(self, name: str, value: str, x: float, y: float, size: float = 9):
        if name not in self.field_names:
            self.field_names.append(name)
        self.c.acroForm.radio(
            name=name,
            tooltip=f"{name}:{value}",
            value=value,
            selected=False,
            x=x,
            y=y,
            size=size,
            buttonStyle="check",
            borderColor=LINE,
            fillColor=white,
            textColor=black,
        )

    def check_options(self, prefix: str, items: list[tuple[str, str]], cols: int = 2):
        col_w = CONTENT_W / cols
        row_h = 14
        i = 0
        while i < len(items):
            self.ensure(row_h + 6)
            self.y -= 2
            btn_y = self.y - 10
            for col in range(cols):
                if i + col >= len(items):
                    break
                slug, label = items[i + col]
                x = MARGIN_L + col * col_w
                self.checkbox(f"{prefix}__{slug}", x, btn_y, 9)
                self.c.setFont("Helvetica", 7)
                self.c.drawString(
                    x + 12,
                    btn_y + 1.5,
                    _truncate(self.c, label, col_w - 16, 7),
                )
            i += cols
            self.y = btn_y - 6

    def radio_options(self, name: str, options: list[tuple[str, str]], cols: int = 3):
        col_w = CONTENT_W / cols
        i = 0
        while i < len(options):
            self.ensure(18)
            self.y -= 2
            btn_y = self.y - 10
            for col in range(cols):
                if i + col >= len(options):
                    break
                value, label = options[i + col]
                x = MARGIN_L + col * col_w
                self.radio(name, value, x, btn_y, 9)
                self.c.setFont("Helvetica", 7)
                self.c.drawString(
                    x + 12,
                    btn_y + 1.5,
                    _truncate(self.c, label, col_w - 16, 7),
                )
            i += cols
            self.y = btn_y - 6

    def intro_banner(self, lines: list[str]):
        """Centered notice under the title, wrapped cleanly in a light box."""
        font_size = 8
        leading = 11
        pad_x = 10
        pad_y = 8
        max_w = CONTENT_W - 2 * pad_x

        # Word-wrap into display lines.
        wrapped: list[str] = []
        for paragraph in lines:
            words = paragraph.split()
            current = ""
            for w in words:
                trial = (current + " " + w).strip()
                if self.c.stringWidth(trial, "Helvetica", font_size) > max_w and current:
                    wrapped.append(current)
                    current = w
                else:
                    current = trial
            if current:
                wrapped.append(current)

        text_h = len(wrapped) * leading
        box_h = text_h + 2 * pad_y
        self.ensure(box_h + 14)
        self.y -= 4
        box_bottom = self.y - box_h
        self.c.setFillColor(Color(0.96, 0.97, 0.99))
        self.c.setStrokeColor(Color(0.75, 0.80, 0.88))
        self.c.setLineWidth(0.6)
        self.c.roundRect(MARGIN_L, box_bottom, CONTENT_W, box_h, 4, fill=1, stroke=1)
        self.c.setFillColor(Color(0.2, 0.25, 0.35))
        self.c.setFont("Helvetica", font_size)
        text_top = box_bottom + box_h - pad_y - font_size
        for i, line in enumerate(wrapped):
            self.c.drawCentredString(PAGE_W / 2, text_top - i * leading, line)
        self.c.setFillColor(black)
        self.y = box_bottom - 12

    def finish(self):
        self._footer()
        self.c.save()
        return self.field_names


def build() -> list[str]:
    b = FormBuilder(OUT)
    # Blank header — start content after top margin only.

    b.title("GRADUATE TRACER SURVEY (GTS)", 12)
    b.intro_banner(
        [
            "This copy was generated by the Alumni Engagement and Support System (AESS). "
            "It is based on the Commission on Higher Education (CHED) Graduate Tracer Survey (GTS) "
            "template and is auto-filled from alumni survey responses for campus records, "
            "accreditation, and reporting. It is not an official CHED-issued form.",
        ]
    )

    # —— A ——
    b.section("A. GENERAL INFORMATION")
    b.labeled_line("1. Name", "fullName", h=16)
    b.label("2. Permanent Address", bold=True)
    b.text_row("permanentAddress", h=32, multiline=True)
    b.labeled_line("3. E-mail Address", "email", h=14)
    b.labeled_line("4. Telephone or Contact Number(s)", "contactNumber", h=14)
    b.labeled_line("5. Mobile Number", "mobileNumber", h=14)

    b.label("6. Civil Status", bold=True)
    b.radio_options(
        "civilStatus",
        [
            ("single", "Single"),
            ("married", "Married"),
            ("separated", "Separated"),
            ("single-parent", "Single Parent"),
            ("widowed", "Widow or Widower"),
        ],
        cols=3,
    )
    b.gap(4)

    b.label("7. Sex", bold=True)
    b.radio_options("sex", [("male", "Male"), ("female", "Female")], cols=4)
    b.gap(4)

    b.label("8. Birthday (Month / Day / Year)", bold=True)
    b.ensure(28)
    b.y -= 2
    field_h = 14
    field_y = b.y - field_h
    b.c.setFont("Helvetica", 7)
    b.c.drawString(MARGIN_L, field_y + 3, "Month")
    b.text("birthMonth", MARGIN_L + 32, field_y, 44, field_h)
    b.c.drawString(MARGIN_L + 86, field_y + 3, "Day")
    b.text("birthDay", MARGIN_L + 108, field_y, 44, field_h)
    b.c.drawString(MARGIN_L + 162, field_y + 3, "Year")
    b.text("birthYear", MARGIN_L + 186, field_y, 54, field_h)
    b.y = field_y - 10

    b.label("9. Region of Origin", bold=True)
    b.text_row("region", h=14, width=240)
    b.gap(2)

    b.labeled_line("10. Province", "province", h=14)

    b.label("11. Location of Residence", bold=True)
    b.radio_options(
        "residenceType",
        [("city", "City"), ("municipality", "Municipality")],
        cols=4,
    )

    # —— B ——
    b.section("B. EDUCATIONAL BACKGROUND")
    b.label("12. Educational Attainment (Baccalaureate Degree only)", bold=True)
    b.ensure(20)
    cols = [
        ("Degree(s) & Specialization(s)", 0.34),
        ("College or University", 0.30),
        ("Year Graduated", 0.14),
        ("Honor(s) or Award(s) Received", 0.22),
    ]
    b.c.setFont("Helvetica-Bold", 6.5)
    x = MARGIN_L
    for title, frac in cols:
        b.c.drawString(x + 1, b.y - 7, title[:30])
        x += CONTENT_W * frac
    b.y -= 12

    edu_fields = [
        ("degree", "collegeUniversity", "yearGraduated", "honors"),
        ("degree2", "collegeUniversity2", "yearGraduated2", "honors2"),
        ("degree3", "collegeUniversity3", "yearGraduated3", "honors3"),
    ]
    for names in edu_fields:
        heights = 20
        b.ensure(heights + 10)
        b.y -= 2
        field_y = b.y - heights
        x = MARGIN_L
        fracs = [0.34, 0.30, 0.14, 0.22]
        for name, frac in zip(names, fracs):
            w = CONTENT_W * frac - 3
            b.text(name, x, field_y, w, heights)
            x += CONTENT_W * frac
        b.y = field_y - 6

    b.gap(6)
    b.label("13. Professional Examination(s) Passed", bold=True)
    b.ensure(14)
    b.c.setFont("Helvetica-Bold", 6.5)
    b.c.drawString(MARGIN_L, b.y - 7, "Name of Examination")
    b.c.drawString(MARGIN_L + CONTENT_W * 0.50, b.y - 7, "Date Taken")
    b.c.drawString(MARGIN_L + CONTENT_W * 0.72, b.y - 7, "Rating")
    b.y -= 12
    for i in (1, 2, 3):
        h = 14
        b.ensure(h + 10)
        b.y -= 2
        field_y = b.y - h
        b.text(f"boardExam{i}_examName", MARGIN_L, field_y, CONTENT_W * 0.48, h)
        b.text(
            f"boardExam{i}_dateTaken",
            MARGIN_L + CONTENT_W * 0.50,
            field_y,
            CONTENT_W * 0.20,
            h,
        )
        b.text(
            f"boardExam{i}_rating",
            MARGIN_L + CONTENT_W * 0.72,
            field_y,
            CONTENT_W * 0.26,
            h,
        )
        b.y = field_y - 6

    b.new_page()
    b.label(
        "14. Reason(s) for taking the course(s) or pursuing degree(s). "
        "You may check more than one answer.",
        bold=True,
    )
    b.ensure(16)
    b.c.setFont("Helvetica-Bold", 7)
    b.c.drawString(MARGIN_L + CONTENT_W * 0.58, b.y - 7, "Undergraduate/AB/BS")
    b.c.drawString(MARGIN_L + CONTENT_W * 0.80, b.y - 7, "Graduate/MS/MA/PhD")
    b.y -= 14
    for slug, label in COURSE_REASON_SLUGS:
        b.ensure(16)
        b.y -= 1
        btn_y = b.y - 10
        b.c.setFont("Helvetica", 6.5)
        b.c.drawString(MARGIN_L, btn_y + 1.5, _truncate(b.c, label, CONTENT_W * 0.55, 6.5))
        b.checkbox(f"courseReasons__{slug}", MARGIN_L + CONTENT_W * 0.62, btn_y, 9)
        b.checkbox(f"courseReasonsGrad__{slug}", MARGIN_L + CONTENT_W * 0.84, btn_y, 9)
        b.y = btn_y - 5

    # Official paper uses a write-in line for "Others" (no checkbox).
    b.ensure(16)
    b.c.setFont("Helvetica", 7)
    b.c.drawString(MARGIN_L, b.y - 7, "Others, please specify:")
    b.y -= 12
    b.text_row("courseReasonsOther", h=16)
    b.gap(4)

    # —— C ——
    b.section("C. TRAINING(S)/ADVANCE STUDIES ATTENDED AFTER COLLEGE")
    b.label(
        "15a. Please list down all professional or work-related training program(s) "
        "including advance studies you have attended after college.",
        bold=True,
    )
    b.note("You may use extra sheet if needed.")
    b.ensure(14)
    b.c.setFont("Helvetica-Bold", 6.5)
    b.c.drawString(MARGIN_L, b.y - 7, "Title of Training or Advance Study")
    b.c.drawString(MARGIN_L + CONTENT_W * 0.42, b.y - 7, "Duration and Credits Earned")
    b.c.drawString(MARGIN_L + CONTENT_W * 0.68, b.y - 7, "Institution / College / University")
    b.y -= 12
    for i in (1, 2, 3):
        h = 14
        b.ensure(h + 10)
        b.y -= 2
        field_y = b.y - h
        b.text(f"training{i}_title", MARGIN_L, field_y, CONTENT_W * 0.40, h)
        b.text(
            f"training{i}_duration",
            MARGIN_L + CONTENT_W * 0.42,
            field_y,
            CONTENT_W * 0.24,
            h,
        )
        b.text(
            f"training{i}_institution",
            MARGIN_L + CONTENT_W * 0.68,
            field_y,
            CONTENT_W * 0.30,
            h,
        )
        b.y = field_y - 6

    b.gap(6)
    b.label("15b. What made you pursue advance studies?", bold=True)
    b.radio_options(
        "advancedStudyReason",
        [
            ("promotion", "For promotion"),
            ("development", "For professional development"),
            ("other", "Others, please specify"),
        ],
        cols=2,
    )
    b.text_row("advancedStudyOther", h=14)
    b.gap(4)

    # —— D ——
    b.section("D. EMPLOYMENT DATA")
    b.label("16. Are you presently employed?", bold=True)
    b.radio_options(
        "employmentStatus",
        [
            ("employed", "Yes"),
            ("unemployed", "No"),
            ("never-employed", "Never Employed"),
        ],
        cols=3,
    )
    b.note(
        "If NO or NEVER BEEN EMPLOYED, proceed to Question 17. If YES, proceed to Questions 18 to 22."
    )
    b.gap(4)

    b.label(
        "17. Please state reason(s) why you are not yet employed. You may check more than one answer.",
        bold=True,
    )
    b.check_options(
        "unemployedReasons",
        [
            ("further-study", "Advance or further study"),
            ("family", "Family concern and decided not to find a job"),
            ("health", "Health-related reason(s)"),
            ("experience", "Lack of work experience"),
            ("no-opportunity", "No job opportunity"),
            ("not-looking", "Did not look for a job"),
            ("other", "Other reason(s), please specify"),
        ],
        cols=1,
    )
    b.text_row("unemployedReasonsOther", h=14)

    b.new_page()
    b.label("18. Present Employment Status", bold=True)
    b.radio_options(
        "presentEmploymentType",
        [
            ("regular", "Regular or Permanent"),
            ("temporary", "Temporary"),
            ("casual", "Casual"),
            ("contractual", "Contractual"),
            ("self-employed", "Self-employed"),
        ],
        cols=2,
    )
    b.gap(4)
    b.label(
        "If self-employed, what skills acquired in college were you able to apply in your work?",
        bold=False,
    )
    b.text_row("selfEmployedSkills", h=36, multiline=True)

    b.labeled_line(
        "19. Present occupation (Ex. Grade School Teacher, Electrical Engineer, Self-employed)",
        "occupation",
        h=18,
    )

    b.label(
        "20. Major line of business of the company you are presently employed in. Check one only.",
        bold=True,
    )
    b.text_row("businessLine", h=14)
    b.gap(2)

    b.label("21. Place of work", bold=True)
    b.radio_options("placeOfWork", [("local", "Local"), ("abroad", "Abroad")], cols=4)
    b.gap(4)

    b.label("22. Is this your first job after college?", bold=True)
    b.radio_options("isFirstJob", [("yes", "Yes"), ("no", "No")], cols=4)
    b.note("If NO, proceed to Questions 25 and 27. If YES, proceed to Question 23.")
    b.gap(4)

    b.label(
        "23. What are your reason(s) for staying on the job? You may check more than one answer.",
        bold=True,
    )
    b.check_options(
        "stayingReasons",
        [
            ("salary", "Salaries and benefits"),
            ("challenge", "Career challenge"),
            ("skill", "Related to special skill"),
            ("course", "Related to course or program of study"),
            ("proximity", "Proximity to residence"),
            ("peer", "Peer influence"),
            ("family", "Family influence"),
            ("other", "Other reason(s), please specify"),
        ],
        cols=2,
    )
    b.text_row("stayingReasonsOther", h=14)
    b.note("Please proceed to Question 24.")
    b.gap(4)

    b.label("24a. Is your first job related to the course you took up in college?", bold=True)
    b.radio_options("firstJobRelated", [("yes", "Yes"), ("no", "No")], cols=4)
    b.note("If NO, proceed to Question 25.")
    b.gap(4)

    b.label(
        "24b. What were your reasons for accepting the job? You may check more than one answer.",
        bold=True,
    )
    b.check_options(
        "acceptingReasons",
        [
            ("salary", "Salaries & benefits"),
            ("challenge", "Career challenge"),
            ("skill", "Related to special skills"),
            ("proximity", "Proximity to residence"),
            ("other", "Other reason(s), please specify"),
        ],
        cols=2,
    )
    b.text_row("acceptingReasonsOther", h=14)
    b.gap(4)

    b.label(
        "25. What were your reason(s) for changing job? You may check more than one answer.",
        bold=True,
    )
    b.check_options(
        "changingReasons",
        [
            ("salary", "Salaries & benefits"),
            ("challenge", "Career challenge"),
            ("skill", "Related to special skills"),
            ("proximity", "Proximity to residence"),
            ("other", "Other reason(s), please specify"),
        ],
        cols=2,
    )
    b.text_row("changingReasonsOther", h=14)

    b.new_page()
    b.note("Note: Official CHED form has no item 26 in this section (numbering jumps 25 to 27).")
    b.gap(4)

    b.label("27. How long did you stay in your first job?", bold=True)
    b.radio_options(
        "firstJobDuration",
        [
            ("lt1mo", "Less than a month"),
            ("1-6mo", "1 to 6 months"),
            ("7-11mo", "7 to 11 months"),
            ("1-2yr", "1 year to less than 2 years"),
            ("2-3yr", "2 years to less than 3 years"),
            ("3-4yr", "3 years to less than 4 years"),
            ("other", "Others, please specify"),
        ],
        cols=2,
    )
    b.text_row("firstJobDurationOther", h=14)
    b.gap(4)

    b.label("28. How did you find your first job?", bold=True)
    b.radio_options(
        "howFoundFirstJob",
        [
            ("ad", "Response to an advertisement"),
            ("walk-in", "As walk-in applicant"),
            ("referral", "Recommended by someone"),
            ("friends", "Information from friends"),
            ("school", "Arranged by school's job placement officer"),
            ("family-business", "Family business"),
            ("peso", "Job Fair or Public Employment Service Office (PESO)"),
            ("other", "Others, please specify"),
        ],
        cols=1,
    )
    b.text_row("howFoundFirstJobOther", h=14)
    b.gap(4)

    b.label("29. How long did it take you to land your first job?", bold=True)
    b.radio_options(
        "timeToLandFirstJob",
        [
            ("lt1mo", "Less than a month"),
            ("1-6mo", "1 to 6 months"),
            ("7-11mo", "7 to 11 months"),
            ("1-2yr", "1 year to less than 2 years"),
            ("2-3yr", "2 years to less than 3 years"),
            ("3-4yr", "3 years to less than 4 years"),
            ("other", "Others, please specify"),
        ],
        cols=2,
    )
    b.text_row("timeToLandFirstJobOther", h=14)
    b.gap(4)

    b.label("30. Job Level Position", bold=True)
    b.ensure(16)
    b.c.setFont("Helvetica-Bold", 7)
    b.c.drawString(MARGIN_L + CONTENT_W * 0.45, b.y - 7, "30.1 First Job")
    b.c.drawString(MARGIN_L + CONTENT_W * 0.70, b.y - 7, "30.2 Current / Present Job")
    b.y -= 14
    levels = [
        ("rank", "Rank or Clerical"),
        ("professional", "Professional, Technical or Supervisory"),
        ("managerial", "Managerial or Executive"),
        ("self-employed", "Self-employed"),
    ]
    for value, label in levels:
        b.ensure(16)
        b.y -= 1
        btn_y = b.y - 10
        b.c.setFont("Helvetica", 7)
        b.c.drawString(MARGIN_L, btn_y + 1.5, label)
        b.radio("firstJobLevel", value, MARGIN_L + CONTENT_W * 0.50, btn_y, 9)
        b.radio("currentJobLevel", value, MARGIN_L + CONTENT_W * 0.75, btn_y, 9)
        b.y = btn_y - 5

    b.gap(6)
    b.label(
        "31. What is your initial gross monthly earning in your first job after college?",
        bold=True,
    )
    b.radio_options(
        "initialSalary",
        [
            ("lt5k", "Below P5,000.00"),
            ("5-10k", "P5,000.00 to less than P10,000.00"),
            ("10-15k", "P10,000.00 to less than P15,000.00"),
            ("15-20k", "P15,000.00 to less than P20,000.00"),
            ("20-25k", "P20,000.00 to less than P25,000.00"),
            ("25k+", "P25,000.00 and above"),
        ],
        cols=1,
    )
    b.gap(4)

    b.label("32. Was the curriculum you had in college relevant to your first job?", bold=True)
    b.radio_options("curriculumRelevant", [("yes", "Yes"), ("no", "No")], cols=4)
    b.note("If NO, please proceed to Question 34.")

    b.new_page()
    b.label(
        "33. If YES, what competencies learned in college did you find very useful in your first job? "
        "You may check more than one answer.",
        bold=True,
    )
    b.check_options(
        "usefulCompetencies",
        [
            ("communication", "Communication skills"),
            ("human-relations", "Human Relations skills"),
            ("entrepreneurial", "Entrepreneurial skills"),
            ("it", "Information Technology skills"),
            ("problem-solving", "Problem-solving skills"),
            ("critical-thinking", "Critical Thinking skills"),
            ("other", "Other skills, please specify"),
        ],
        cols=1,
    )
    b.text_row("usefulCompetenciesOther", h=14)
    b.gap(6)

    b.label("34. List down suggestions to further improve your course curriculum", bold=True)
    b.text_row("curriculumSuggestions", h=80, multiline=True)

    b.gap(14)
    b.c.setFont("Helvetica-Oblique", 8)
    b.c.drawString(
        MARGIN_L,
        b.y - 8,
        "Thank you for taking time out to fill out this questionnaire. Please return this GTS to your Institution.",
    )
    b.y -= 16

    return b.finish()


if __name__ == "__main__":
    names = build()
    print(f"Wrote {OUT}")
    print(f"Tracked field names: {len(names)}")
    for n in names:
        print(n)
