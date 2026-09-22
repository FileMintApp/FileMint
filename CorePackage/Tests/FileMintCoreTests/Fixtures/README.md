# Synthetic Office documents

- `weekly.docx`: heading, paragraph, table and literal `{{date}}` text; generated
  with python-docx using the local test runtime.
- `expenses.xlsx`: a styled header, numeric cell and `SUM` formula; generated
  with openpyxl using the local test runtime.

These are test-only inputs with no user data. Neither generation library is an
application dependency. Tests import the packages, remove the source, create
independent copies and compare all bytes; malformed ZIP/XML cases are generated
in the test itself. The fixtures are never bundled into the FileMint app.
