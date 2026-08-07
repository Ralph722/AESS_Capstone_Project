/// Label / option → PDF AcroForm export-value maps for CHED GTS v3.1.0.
///
/// App answers store human-readable labels from [ChedGtsBuiltin] /
/// [GtsConstants]. The official-aligned PDF uses slug export names
/// (`/single`, `/lt1mo`) and official option strings (ARMM, full business lines).
library;

/// App civil-status label → PDF `civilStatus` export value.
const kChedGtsPdfCivilStatus = <String, String>{
  'Single': '/single',
  'Married': '/married',
  'Separated': '/separated',
  'Single Parent': '/single-parent',
  'Widow or Widower': '/widowed',
};

const kChedGtsPdfSex = <String, String>{
  'Male': '/male',
  'Female': '/female',
};

/// App region label → PDF `region` text value (official form uses ARMM).
const kChedGtsPdfRegion = <String, String>{
  'Region 1': 'Region 1',
  'Region 2': 'Region 2',
  'Region 3': 'Region 3',
  'Region 4': 'Region 4',
  'Region 5': 'Region 5',
  'Region 6': 'Region 6',
  'Region 7': 'Region 7',
  'Region 8': 'Region 8',
  'Region 9': 'Region 9',
  'Region 10': 'Region 10',
  'Region 11': 'Region 11',
  'Region 12': 'Region 12',
  'NCR': 'NCR',
  'CAR': 'CAR',
  'ARMM': 'ARMM',
  'BARMM': 'ARMM',
  'CARAGA': 'CARAGA',
};

const kChedGtsPdfResidenceType = <String, String>{
  'City': '/city',
  'Municipality': '/municipality',
};

const kChedGtsPdfAdvancedStudyReason = <String, String>{
  'For promotion': '/promotion',
  'For professional development': '/development',
  'Others, please specify': '/other',
};

const kChedGtsPdfEmploymentStatus = <String, String>{
  'Yes': '/employed',
  'No': '/unemployed',
  'Never Employed': '/never-employed',
};

const kChedGtsPdfPresentEmploymentType = <String, String>{
  'Regular or Permanent': '/regular',
  'Temporary': '/temporary',
  'Casual': '/casual',
  'Contractual': '/contractual',
  'Self-employed': '/self-employed',
};

/// App line-of-business labels → PDF `businessLine` strings (official wording).
const kChedGtsPdfBusinessLine = <String, String>{
  'Agriculture, Hunting and Forestry': 'Agriculture, Hunting and Forestry',
  'Fishing': 'Fishing',
  'Mining and Quarrying': 'Mining and Quarrying',
  'Manufacturing': 'Manufacturing',
  'Electricity, Gas and Water Supply': 'Electricity, Gas and Water Supply',
  'Construction': 'Construction',
  'Wholesale and Retail Trade, repair of motor vehicles, motorcycles and personal and household goods':
      'Wholesale and Retail Trade, repair of motor vehicles, motorcycles and personal and household goods',
  'Hotels and Restaurants': 'Hotels and Restaurants',
  'Transport Storage and Communication': 'Transport Storage and Communication',
  'Financial Intermediation': 'Financial Intermediation',
  'Real Estate, Renting and Business Activities':
      'Real Estate, Renting and Business Activities',
  'Public Administration and Defense; Compulsory Social Security':
      'Public Administration and Defense; Compulsory Social Security',
  'Education': 'Education',
  'Health and Social Work': 'Health and Social Work',
  'Other Community, Social and Personal Service Activities':
      'Other Community, Social and Personal Service Activities',
  'Private Households with Employed Persons':
      'Private Households with Employed Persons',
  'Extra-territorial Organizations and Bodies':
      'Extra-territorial Organizations and Bodies',
};

const kChedGtsPdfPlaceOfWork = <String, String>{
  'Local': '/local',
  'Abroad': '/abroad',
};

const kChedGtsPdfYesNo = <String, String>{
  'Yes': '/yes',
  'No': '/no',
};

const kChedGtsPdfDuration = <String, String>{
  'Less than a month': '/lt1mo',
  '1 to 6 months': '/1-6mo',
  '7 to 11 months': '/7-11mo',
  '1 year to less than 2 years': '/1-2yr',
  '2 years to less than 3 years': '/2-3yr',
  '3 years to less than 4 years': '/3-4yr',
  'Others, please specify': '/other',
};

const kChedGtsPdfHowFoundFirstJob = <String, String>{
  'Response to an advertisement': '/ad',
  'As walk-in applicant': '/walk-in',
  'Recommended by someone': '/referral',
  'Information from friends': '/friends',
  "Arranged by school's job placement officer": '/school',
  'Family business': '/family-business',
  'Job Fair or Public Employment Service Office (PESO)': '/peso',
  'Others, please specify': '/other',
};

const kChedGtsPdfJobLevel = <String, String>{
  'Rank or Clerical': '/rank',
  'Professional, Technical or Supervisory': '/professional',
  'Managerial or Executive': '/managerial',
  'Self-employed': '/self-employed',
};

const kChedGtsPdfInitialSalary = <String, String>{
  'Below P5,000.00': '/lt5k',
  'P5,000.00 to less than P10,000.00': '/5-10k',
  'P10,000.00 to less than P15,000.00': '/10-15k',
  'P15,000.00 to less than P20,000.00': '/15-20k',
  'P20,000.00 to less than P25,000.00': '/20-25k',
  'P25,000.00 and above': '/25k+',
};

/// `ched_14` matrix row label → undergraduate `courseReasons__*` PDF field.
const kChedGtsPdfCourseReasonField = <String, String>{
  'High grades in the course or subject area(s) related to the course':
      'courseReasons__high-grades',
  'Good grades in high school': 'courseReasons__hs-grades',
  'Influence of parents or relatives': 'courseReasons__parents',
  'Peer Influence': 'courseReasons__peers',
  'Inspired by a role model': 'courseReasons__role-model',
  'Strong passion for the profession': 'courseReasons__passion',
  'Prospect for immediate employment': 'courseReasons__employment-prospect',
  'Status or prestige of the profession': 'courseReasons__prestige',
  'Availability of course offering in chosen institution':
      'courseReasons__availability',
  'Prospect of career advancement': 'courseReasons__career-advancement',
  'Affordable for the family': 'courseReasons__affordability',
  'Prospect of attractive compensation': 'courseReasons__compensation',
  'Opportunity for employment abroad': 'courseReasons__abroad',
  'No particular choice or no better idea': 'courseReasons__no-choice',
};

/// Same rows → graduate column checkboxes.
const kChedGtsPdfCourseReasonGradField = <String, String>{
  'High grades in the course or subject area(s) related to the course':
      'courseReasonsGrad__high-grades',
  'Good grades in high school': 'courseReasonsGrad__hs-grades',
  'Influence of parents or relatives': 'courseReasonsGrad__parents',
  'Peer Influence': 'courseReasonsGrad__peers',
  'Inspired by a role model': 'courseReasonsGrad__role-model',
  'Strong passion for the profession': 'courseReasonsGrad__passion',
  'Prospect for immediate employment':
      'courseReasonsGrad__employment-prospect',
  'Status or prestige of the profession': 'courseReasonsGrad__prestige',
  'Availability of course offering in chosen institution':
      'courseReasonsGrad__availability',
  'Prospect of career advancement': 'courseReasonsGrad__career-advancement',
  'Affordable for the family': 'courseReasonsGrad__affordability',
  'Prospect of attractive compensation': 'courseReasonsGrad__compensation',
  'Opportunity for employment abroad': 'courseReasonsGrad__abroad',
  'No particular choice or no better idea': 'courseReasonsGrad__no-choice',
};

/// Multi-select option label → PDF checkbox field name.
const kChedGtsPdfUnemployedReasonField = <String, String>{
  'Advance or further study': 'unemployedReasons__further-study',
  'Family concern and decided not to find a job': 'unemployedReasons__family',
  'Health-related reason(s)': 'unemployedReasons__health',
  'Lack of work experience': 'unemployedReasons__experience',
  'No job opportunity': 'unemployedReasons__no-opportunity',
  'Did not look for a job': 'unemployedReasons__not-looking',
  'Other reason(s), please specify': 'unemployedReasons__other',
};

const kChedGtsPdfStayingReasonField = <String, String>{
  'Salaries and benefits': 'stayingReasons__salary',
  'Career challenge': 'stayingReasons__challenge',
  'Related to special skill': 'stayingReasons__skill',
  'Related to course or program of study': 'stayingReasons__course',
  'Proximity to residence': 'stayingReasons__proximity',
  'Peer influence': 'stayingReasons__peer',
  'Family influence': 'stayingReasons__family',
  'Other reason(s), please specify': 'stayingReasons__other',
};

const kChedGtsPdfAcceptingReasonField = <String, String>{
  'Salaries & benefits': 'acceptingReasons__salary',
  'Career challenge': 'acceptingReasons__challenge',
  'Related to special skills': 'acceptingReasons__skill',
  'Proximity to residence': 'acceptingReasons__proximity',
  'Other reason(s), please specify': 'acceptingReasons__other',
};

const kChedGtsPdfChangingReasonField = <String, String>{
  'Salaries & benefits': 'changingReasons__salary',
  'Career challenge': 'changingReasons__challenge',
  'Related to special skills': 'changingReasons__skill',
  'Proximity to residence': 'changingReasons__proximity',
  'Other reason(s), please specify': 'changingReasons__other',
};

const kChedGtsPdfUsefulCompetencyField = <String, String>{
  'Communication skills': 'usefulCompetencies__communication',
  'Human Relations skills': 'usefulCompetencies__human-relations',
  'Entrepreneurial skills': 'usefulCompetencies__entrepreneurial',
  'Information Technology skills': 'usefulCompetencies__it',
  'Problem-solving skills': 'usefulCompetencies__problem-solving',
  'Critical Thinking skills': 'usefulCompetencies__critical-thinking',
  'Other skills, please specify': 'usefulCompetencies__other',
};

/// Matrix column used for undergraduate course reasons on the PDF.
const kChedGtsPdfCourseReasonUgColumn = 'Undergraduate/AB/BS';

const kChedGtsPdfCourseReasonGradColumn = 'Graduate/MS/MA/PhD';

const kChedGtsPdfJobLevelFirstColumn = '30.1. First Job';
const kChedGtsPdfJobLevelCurrentColumn = '30.2. Current or Present Job';

/// Table column keys used when flattening `tableRows` answers.
const kChedGtsPdfEduDegreeCol = 'Degree(s) & Specialization(s)';
const kChedGtsPdfEduCollegeCol = 'College or University';
const kChedGtsPdfEduYearCol = 'Year Graduated';
const kChedGtsPdfEduHonorsCol = 'Honor(s) or Award(s) Received';

const kChedGtsPdfExamNameCol = 'Name of Examination';
const kChedGtsPdfExamDateCol = 'Date Taken';
const kChedGtsPdfExamRatingCol = 'Rating';

const kChedGtsPdfTrainingTitleCol = 'Title of Training or Advance Study';
const kChedGtsPdfTrainingDurationCol = 'Duration and Credits Earned';
const kChedGtsPdfTrainingInstitutionCol =
    'Name of Training Institution/College/University';

/// PDF-only / administrative fields with no `ched_*` answer source.
const kChedGtsPdfExplicitlyUnmappedAnswerKeys = <String>{};

/// PDF fields that are intentionally left blank by the mapper.
const kChedGtsPdfTemplateOnlyFields = <String>{};
