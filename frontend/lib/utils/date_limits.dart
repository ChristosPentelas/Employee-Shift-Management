// How far ahead the app's date pickers reach (B23).
//
// The pickers used to end on a hard-coded year - DateTime(2027) - which
// quietly shrank the choice every day and, once today passed it, made
// firstDate later than lastDate: a Flutter assertion error, and a dialog that
// no longer opens.
//
// Today is a parameter, not DateTime.now() inside, so a test can ask "what
// happens on 1 January 2027?" without waiting for it.
DateTime latestPickableDate(DateTime today) => today.add(const Duration(days: 365));
