import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_columns.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

AlumniMember _member(
  String name, {
  String batch = '2023',
  String? uid,
  bool registered = true,
  String? registeredEmail,
  String email = '',
  String contact = '',
}) => AlumniMember(
  id: 'm-$name',
  fullName: name,
  course: 'BSIT',
  studentId: 'S-$name',
  authUid: uid,
  isRegisteredUser: registered,
  registeredEmail: registeredEmail,
  emailAddress: email,
  contactNumber: contact,
  batchYear: batch,
  createdAt: DateTime(2020),
);

GtsListResponse _response(
  String uid,
  Map<String, dynamic> answers, {
  String wave = 'w2',
  DateTime? at,
}) => GtsListResponse(
  userId: uid,
  surveyId: wave,
  responseId: '$uid-$wave',
  submittedAt: at ?? DateTime.utc(2026, 6, 15, 2),
  answers: answers,
);

GtsAlumniListResult _list(
  List<AlumniMember> roster,
  List<GtsListResponse> responses, {
  GtsListConfig config = const GtsListConfig(surveyId: 'w2'),
}) => GtsAlumniList.build(
  config,
  roster: roster,
  responses: responses,
  waveIds: const ['w2', 'w1'],
  waveLabels: const {'w2': 'Tracer 2026', 'w1': 'Tracer 2025'},
);

GtsListColumn _col(String key) => GtsListColumns.byKey(key)!;

/// Cell for [key] in the only row of a one-graduate list.
String _cell(String key, Map<String, dynamic> answers) {
  final result = _list(
    [_member('Juan Dela Cruz', uid: 'u1')],
    [_response('u1', answers)],
  );
  return GtsListColumns.cell(_col(key), result.rows.single);
}

const _employed = {'ched_16': ChedGtsBuiltin.yes};

void main() {
  group('column dictionary', () {
    test('every CHED item 1-34 has a column; specify boxes do not', () {
      final keys = {for (final c in GtsListColumns.all) c.key};
      for (final item in ChedGtsBuiltin.items) {
        expect(keys.contains(item.id), !item.isOthersSpecify, reason: item.id);
      }
      final numbers = {
        for (final c in GtsListColumns.all)
          if (c.item case final item?) item.chedNumber,
      };
      for (var n = 1; n <= 34; n++) {
        expect(
          numbers.any((s) => s == '$n' || RegExp('^$n[a-z]').hasMatch(s)),
          isTrue,
          reason: 'item $n',
        );
      }
    });

    test('roster columns come first, then the CHED sections in order', () {
      expect(GtsListColumns.groups.first, GtsListColumns.alumniGroup);
      expect(GtsListColumns.groups.length, greaterThanOrEqualTo(5));
      expect(
        GtsListColumns.inGroup(GtsListColumns.alumniGroup).map((c) => c.key),
        containsAll(GtsListConfig.defaultColumns),
      );
      final firstAnswer = GtsListColumns.all.indexWhere((c) => c.isAnswer);
      expect(
        GtsListColumns.all.skip(firstAnswer).every((c) => c.isAnswer),
        isTrue,
      );
    });

    test('headers use the question label, and the number stays searchable', () {
      expect(_col('ched_16').header, 'Presently employed');
      expect(_col('ched_19').header, 'Present occupation');
      expect(_col('ched_20').header, 'Line of business');
      expect(_col('ched_16').header, isNot(contains('16.')));
      expect(_col('ched_16').searchText, '16');
      expect(_col('ched_16').description, contains('presently employed'));
    });

    test('names and contact details are marked personal', () {
      for (final key in [
        GtsListConfig.nameColumn,
        GtsListColumns.studentIdColumn,
        'ched_1',
        'ched_3',
      ]) {
        expect(_col(key).personal, isTrue, reason: key);
      }
      expect(_col('ched_16').personal, isFalse);
      expect(_col(GtsListConfig.batchColumn).personal, isFalse);
    });

    test('resolve keeps order, drops unknown and repeated keys', () {
      const config = GtsListConfig(
        surveyId: 'w2',
        columns: ['ched_19', 'name', 'gone', 'ched_19'],
      );
      expect(GtsListColumns.resolve(config).map((c) => c.key), [
        'ched_19',
        GtsListConfig.nameColumn,
      ]);
      expect(GtsListColumns.unknownKeys(config), ['gone']);
    });

    test('the Name column is titled Name in the table and the picker', () {
      final column = _col(GtsListConfig.nameColumn);
      expect(column.header, 'Name');
      expect(
        GtsListColumns.pickable.any(
          (c) => c.key == GtsListConfig.sectionANameColumn,
        ),
        isFalse,
      );
    });

    test('a saved name column is the Name column', () {
      const config = GtsListConfig(columns: ['name', 'wave', 'email']);
      expect(GtsListColumns.resolve(config).map((c) => c.key), [
        GtsListConfig.nameColumn,
      ]);
      expect(GtsListColumns.unknownKeys(config), ['wave', 'email']);
    });

    test('section A Name folds into the alumni Name column', () {
      const config = GtsListConfig(
        columns: ['ched_1', 'course', GtsListConfig.nameColumn],
      );
      expect(GtsListColumns.resolve(config).map((c) => c.key), [
        GtsListConfig.nameColumn,
        'course',
      ]);
      expect(
        GtsListConfig.migrateColumns(['ched_1', 'untracked_name']),
        [GtsListConfig.nameColumn],
      );
    });
  });

  group('the example row', () {
    test('2023 | Juan Dela Cruz | Yes | AI engineer', () {
      final result = _list(
        [
          _member('Juan Dela Cruz', uid: 'u1'),
          _member('Maria Santos', uid: 'u2'),
          _member('Ana Lopez', uid: 'u3'),
          _member('Jose Rizal', registered: false),
        ],
        [
          _response('u1', {..._employed, 'ched_19': 'AI engineer'}),
          _response('u2', {'ched_16': ChedGtsBuiltin.no}),
        ],
      );
      final columns = GtsListColumns.resolve(
        const GtsListConfig(
          surveyId: 'w2',
          columns: ['year_graduated', 'name', 'ched_16', 'ched_19'],
        ),
      );
      final table = {
        for (final r in result.rows)
          r.name: [for (final c in columns) GtsListColumns.cell(c, r)],
      };
      expect(table['Juan Dela Cruz'], [
        '2023',
        'Juan Dela Cruz',
        'Yes',
        'AI engineer',
      ]);
      expect(table['Maria Santos'], ['2023', 'Maria Santos', 'No', 'Not asked']);
      expect(table['Ana Lopez'], ['2023', 'Ana Lopez', '', '']);
      expect(table['Jose Rizal'], ['2023', 'Jose Rizal', '', '']);
    });
  });

  group('answer cells', () {
    test('asked but left blank is empty, not "Not asked"', () {
      expect(_cell('ched_19', _employed), '');
      expect(_cell('ched_17', _employed), 'Not asked');
    });

    test('single choice: Others text replaces the Others choice', () {
      expect(
        _cell('ched_20', {
          ..._employed,
          'ched_20': ChedGtsBuiltin.othersSpecify,
          'ched_20_other': 'Freelance',
        }),
        'Others: Freelance',
      );
      expect(
        _cell('ched_20', {
          ..._employed,
          'ched_20': ChedGtsBuiltin.othersSpecify,
        }),
        ChedGtsBuiltin.othersSpecify,
      );
    });

    test('stale Others text is ignored when Others was not picked', () {
      final item = ChedGtsBuiltin.byId('ched_20')!;
      expect(
        _cell('ched_20', {
          ..._employed,
          'ched_20': item.options.first,
          'ched_20_other': 'Old text',
        }),
        item.options.first,
      );
    });

    test('a real "Other ..." choice is never replaced', () {
      const choice = 'Other Community, Social and Personal Service Activities';
      expect(_cell('ched_20', {..._employed, 'ched_20': choice}), choice);
    });

    test('multiple choice joins with "; " and merges Others', () {
      expect(
        _cell('ched_17', {
          'ched_16': ChedGtsBuiltin.no,
          'ched_17': ['No job opportunity', ChedGtsBuiltin.otherReasonsSpecify],
          'ched_17_other': 'Caring for family',
        }),
        'No job opportunity; Others: Caring for family',
      );
    });

    test('options with commas stay readable', () {
      expect(
        _cell('ched_17', {
          'ched_16': ChedGtsBuiltin.no,
          'ched_17': [
            'Family concern and decided not to find a job',
            'Lack of work experience',
          ],
        }),
        'Family concern and decided not to find a job; '
        'Lack of work experience',
      );
    });

    test('grid: ticked rows with their columns, Others merged', () {
      final item = ChedGtsBuiltin.byId('ched_14')!;
      final reason = item.matrixRows.first;
      final level = item.matrixColumns.first;
      expect(
        _cell('ched_14', {
          'ched_14': {
            reason: {level: true, item.matrixColumns.last: false},
            ChedGtsBuiltin.othersSpecify: {level: true},
          },
          'ched_14_other': 'Scholarship',
        }),
        '$reason ($level); Others: Scholarship ($level)',
      );
    });

    test('grid: job level for first and current job', () {
      final item = ChedGtsBuiltin.byId('ched_30')!;
      final first = item.matrixColumns.first;
      final current = item.matrixColumns.last;
      expect(
        _cell('ched_30', {
          ..._employed,
          'ched_30': {
            item.matrixRows[0]: {first: true},
            item.matrixRows[1]: {current: true},
            item.matrixRows[2]: {first: false},
          },
        }),
        '${item.matrixRows[0]} ($first); ${item.matrixRows[1]} ($current)',
      );
    });

    test('table rows: values joined by " | ", rows by "; "', () {
      expect(
        _cell('ched_13', {
          'ched_13': [
            {
              'Rating': '85.4',
              'Name of Examination': 'LET',
              'Date Taken': '2024-03',
            },
            {'Name of Examination': 'CSE', 'Date Taken': '', 'Rating': ''},
            {'Name of Examination': '  '},
          ],
        }),
        'LET | 2024-03 | 85.4; CSE',
      );
    });

    test('long text is kept on one line', () {
      expect(
        _cell('ched_34', {'ched_34': 'More labs.\n\n  Update the curriculum.'}),
        'More labs. Update the curriculum.',
      );
    });

    test('a single value stored as a list still shows', () {
      expect(
        _cell('ched_16', {
          'ched_16': [ChedGtsBuiltin.yes],
        }),
        'Yes',
      );
    });
  });

  group('roster cells', () {
    test('answered alumni show Answered, and Name uses their best name', () {
      final result = _list(
        [
          _member('Juan Dela Cruz', uid: 'u1'),
          _member('Jose Rizal', registered: false),
        ],
        [
          _response('u1', _employed),
          _response('u9', {..._employed, 'ched_1': 'Off Roster Person'}),
        ],
      );
      String cell(String name, String key) {
        final row = result.rows.firstWhere((r) => r.name == name);
        return GtsListColumns.cell(_col(key), row);
      }

      expect(cell('Juan Dela Cruz', GtsListConfig.nameColumn), 'Juan Dela Cruz');
      expect(cell('Juan Dela Cruz', 'student_id'), 'S-Juan Dela Cruz');
      expect(cell('Juan Dela Cruz', 'tracer_status'), 'Answered');
      expect(cell('Juan Dela Cruz', 'ched_16'), 'Yes');
      expect(cell('Jose Rizal', GtsListConfig.nameColumn), 'Jose Rizal');
      expect(cell('Jose Rizal', 'ched_1'), '');
      expect(cell('Jose Rizal', 'ched_3'), '');
      expect(
        cell('Jose Rizal', 'tracer_status'),
        GtsTracerStatus.untrackedNotRegistered.label,
      );
      expect(
        cell('Off Roster Person', GtsListConfig.nameColumn),
        'Off Roster Person',
      );
      expect(cell('Off Roster Person', 'ched_1'), 'Off Roster Person');
      expect(
        cell('Off Roster Person', 'tracer_status'),
        GtsTracerStatus.offRoster.label,
      );
    });

    test('one Name column fills every included person', () {
      const config = GtsListConfig(
        surveyId: 'w2',
        columns: [GtsListConfig.nameColumn, 'course'],
      );
      final shown = GtsListColumns.displayColumns(config);
      expect(shown.map((c) => c.header), ['Name', 'Course']);

      final result = GtsAlumniList.build(
        config,
        roster: [
          _member('Catherine Jala', uid: 'u1'),
          _member('Jose Rizal', registered: false),
          _member('Ralph Juab', uid: 'u3'),
        ],
        responses: [
          _response('u3', {..._employed, 'ched_1': 'Ralph Jezron A. Juab'}),
        ],
        waveIds: const ['w2'],
        sectionAByUser: {
          'u1': {'ched_1': 'Catherine J. Jala'},
        },
      );
      String shownName(String rosterName) {
        final row = result.rows.firstWhere(
          (r) => r.member?.fullName == rosterName,
        );
        return GtsListColumns.cell(shown.first, row);
      }

      expect(shownName('Catherine Jala'), 'Catherine J. Jala');
      expect(shownName('Jose Rizal'), 'Jose Rizal');
      expect(shownName('Ralph Juab'), 'Ralph Jezron A. Juab');
    });

    test('turning off includeUntracked hides people who have not answered', () {
      final withUntracked = _list(
        [
          _member('Juan Dela Cruz', uid: 'u1'),
          _member('Ana Lopez', uid: 'u2'),
          _member('Jose Rizal', registered: false),
        ],
        [_response('u1', _employed)],
      );
      final without = _list(
        [
          _member('Juan Dela Cruz', uid: 'u1'),
          _member('Ana Lopez', uid: 'u2'),
          _member('Jose Rizal', registered: false),
        ],
        [_response('u1', _employed)],
        config: const GtsListConfig(surveyId: 'w2', includeUntracked: false),
      );
      expect(withUntracked.rows.map((r) => r.name).toSet(), {
        'Juan Dela Cruz',
        'Ana Lopez',
        'Jose Rizal',
      });
      expect(without.rows.map((r) => r.name), ['Juan Dela Cruz']);
      expect(without.rows.every((r) => !r.status.untracked), isTrue);
    });

    test('date answered', () {
      final result = _list(
        [_member('Juan Dela Cruz', uid: 'u1'), _member('Ana Lopez', uid: 'u2')],
        [_response('u1', _employed, wave: 'w1')],
        config: const GtsListConfig(),
      );
      final juan = result.rows.firstWhere((r) => r.name == 'Juan Dela Cruz');
      final ana = result.rows.firstWhere((r) => r.name == 'Ana Lopez');
      final date = _col(GtsListColumns.answeredOnColumn);
      expect(GtsListColumns.cell(date, juan), matches(r'^2026-06-1[45]$'));
      expect(GtsListColumns.cell(date, ana), '');
    });
  });

  group('sorting by an answer column', () {
    final roster = [
      _member('A', uid: 'a'),
      _member('B', uid: 'b'),
      _member('C', uid: 'c'),
      _member('D', uid: 'd'),
      _member('E', uid: 'e'),
    ];
    final responses = [
      _response('a', {..._employed, 'ched_19': 'teacher'}),
      _response('b', {..._employed, 'ched_19': 'Analyst'}),
      _response('c', {'ched_16': ChedGtsBuiltin.no}),
      _response('d', _employed),
    ];

    List<String> names(bool descending) => [
      for (final r in _list(
        roster,
        responses,
        config: GtsListConfig(
          surveyId: 'w2',
          sortBy: 'ched_19',
          sortDescending: descending,
        ),
      ).rows)
        r.name,
    ];

    test('A to Z, blanks and "Not asked" last', () {
      expect(names(false).take(2), ['B', 'A']);
      expect(names(false).skip(2).toSet(), {'C', 'D', 'E'});
    });

    test('Z to A keeps blanks last', () {
      expect(names(true).take(2), ['A', 'B']);
      expect(names(true).skip(2).toSet(), {'C', 'D', 'E'});
    });

    test('numbers sort by value', () {
      final result = _list(
        [
          _member('Ten', uid: 't', batch: '2010'),
          _member('Nine', uid: 'n', batch: '2009'),
        ],
        [
          _response('t', {'ched_9': '10'}),
          _response('n', {'ched_9': '9'}),
        ],
        config: const GtsListConfig(surveyId: 'w2', sortBy: 'ched_9'),
      );
      expect([for (final r in result.rows) r.name], ['Nine', 'Ten']);
    });
  });
}
