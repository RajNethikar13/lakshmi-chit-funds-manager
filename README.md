# Lakshmi Chit Manager V3

**Lakshmi Chit Manager** is an offline Flutter Android application for managing personal chit-fund business operations. It is designed to keep chit schemes, groups, members, monthly payments, chit lifts/payouts, and business analysis in one local application.

The application uses a local SQLite database, so the core data is stored on the device and does not require a public server or internet connection for normal data management.

---

## 1. Main Purpose

The app is intended for a chit-fund operator who needs to:

- Create reusable chit-scheme templates.
- Create multiple chit groups from those schemes.
- Add, edit, and delete members.
- Track each member's monthly payment status.
- Record the amount received and payment method.
- Record the actual payment date.
- Record when a member receives/lifts the chit amount.
- See how many scheduled months remain after a member's chit lift.
- Track group-level financial activity.
- Analyse collections, payouts, outstanding amounts, and profit.
- Export business data to Excel.
- Create a complete Excel backup and restore the app from that backup.

The app is designed as a **local/offline manager**, not as a public customer-facing application.

---

## 2. Current App Sections

The bottom navigation contains five main sections:

1. **Home**
2. **Groups**
3. **Members**
4. **Schemes**
5. **Analysis**

---

## 3. Home / Dashboard

The Home screen provides a quick overview of the business.

It displays key information such as:

- Active groups.
- Total members.
- Amount received.
- Amount given out.
- Outstanding amount.

The Home screen also contains the data-management actions:

### Full Excel Backup

Creates a complete `.xlsx` backup containing the app's core database information.

The full backup contains these sheets:

- `Templates`
- `Groups`
- `Members`
- `Payments`
- `Ledger`

The Android sharing interface can be used to save the generated Excel file to a suitable location such as Files, Drive, or another storage destination available on the phone.

### Restore

Allows a previously created full Excel backup to be selected from the phone and restored into the app.

The restore process rebuilds the local database while preserving the relationships between:

- Schemes/templates.
- Groups.
- Members.
- Payments.
- Ledger transactions.

**Important:** A full backup should be used for restoring the entire app. Excel reports exported from individual sections are intended for inspection/reporting and are not full restore files.

---

# 4. Schemes

The **Schemes** section manages reusable chit-scheme templates.

A scheme contains information such as:

- Scheme name.
- Total number of months.
- Number of members.
- Monthly installment.
- Due day.
- Maximum amount a member can receive at the end of the total scheme period.

### Example

A typical scheme can be configured as:

| Setting | Example |
|---|---:|
| Scheme | 25 Months - ₹16,000 |
| Duration | 25 months |
| Members | 25 |
| Monthly installment | ₹16,000 |
| Due day | 5 |
| Maximum payout | ₹5,00,000 |

The scheme can then be reused when creating different groups.

### Maximum Payout

V3 adds a **maximum payout per person** field to the scheme.

This allows the operator to record the maximum amount a member is expected to receive by the end of the scheme.

For example:

> Maximum payout = ₹5,00,000

This is separate from the monthly installment and can be edited when creating or updating a scheme.

---

# 5. Groups

The **Groups** section manages individual chit groups created from schemes.

A group contains information such as:

- Group name.
- Selected scheme.
- Start date.
- Group members.
- Group payment activity.
- Chit lift/payout information.

Groups are tappable so the operator can open a group's details and work with its members.

### Group-level Excel export

The Groups section provides an Excel export option.

The exported workbook includes the relational information needed to inspect the selected group together with its related scheme, members, payments, and ledger information.

---

# 6. Members

The **Members** section provides a list of members across the chit groups.

Members can be:

- Added.
- Edited.
- Deleted.
- Opened to view detailed information.
- Contacted using the available WhatsApp action.

Member information includes details such as:

- Name.
- Mobile number.
- Chit scheme/group relationship.
- Payment history.
- Chit lift information.

### Member Excel export

The Members section provides an Excel export option so member and related transaction data can be inspected or stored outside the application.

---

# 7. Monthly Payment Tracking

Each member has a detailed monthly payment screen.

The payment matrix covers the months of the member's selected chit scheme.

For each month, the operator can record:

- **Paid**
- **Partial**
- **Pending**
- Amount received.
- Balance remaining.
- Payment method.
- Payment date.

### Payment date

V3 adds a payment-date selector to the payment-entry dialog.

The operator can record the actual date on which the payment was received rather than relying only on the scheduled due date.

This date is stored with the payment record and is also available for analysis and Excel backup.

---

# 8. Payment Methods

The payment entry supports recording the payment method together with the payment amount and status.

This allows the operator to maintain a more complete transaction history rather than storing only a Paid/Pending flag.

---

# 9. Chit Lift / Payout

The app allows a member's chit lift to be recorded at a particular month.

The lift information records the amount given to the member and the relevant month.

The app can then show the scheduled months remaining after the member's chit lift.

This is useful for identifying members who have already received their chit amount while still having future scheduled installments in the scheme.

The lift transaction is also recorded in the financial ledger so it can contribute to business-level financial analysis.

---

# 10. Business Analysis

The **Analysis** section provides business-level financial information.

V3 adds flexible analysis periods:

- **Monthly**
- **Quarterly**
- **Yearly**

The analysis can also be filtered by:

- Year.
- Month when applicable.
- Quarter when applicable.
- Specific group.
- Specific scheme.

### Main analysis values

The analysis can calculate/display information including:

- Total amount received.
- Total amount given out.
- Net amount.
- Outstanding amount.
- Group-level profit information.

---

# 11. Completed Group Profit

V3 introduces a specific profit calculation for completed groups.

A group is considered completed when its scheduled scheme end date has been reached based on:

- Group start date.
- Scheme duration in months.

For a completed group, the app calculates:

**Profit = Total amount received from group members − Total amount given out to group members**

For example, if a completed group has:

- Total received = ₹40,00,000
- Total given out = ₹37,50,000

then the recorded group profit is:

**₹2,50,000**

The calculation is based on transactions actually recorded in the application's payment and ledger data.

Therefore, missing or incorrectly entered transactions will affect the calculated result.

---

# 12. Excel Export

V3 adds Excel export functionality to the major sections of the application.

The purpose is to allow the operator to inspect, store, share, or archive app data outside the application.

### Available exports

| Section | Export purpose |
|---|---|
| Home | Complete backup |
| Groups | Group-related data and relational context |
| Members | Member and related transaction data |
| Schemes | Scheme/template and group context |
| Analysis | Analysis metrics and group-profit information |

The generated files use the `.xlsx` format.

---

# 13. Complete Excel Backup and Restore

The full backup/restore system is intended to provide a way to protect the application's local data.

### Backup contents

A full backup contains:

1. **Templates** — scheme definitions.
2. **Groups** — chit groups and their scheme relationships.
3. **Members** — group members.
4. **Payments** — monthly payment records.
5. **Ledger** — financial transactions such as received payments and chit payouts.

### Restore process

The restore process:

1. Reads the selected `.xlsx` file.
2. Checks that the required backup sheets are present.
3. Recreates the database tables from the backup.
4. Restores original IDs.
5. Restores group/member/template relationships.
6. Restores payment records.
7. Restores ledger transactions.

The goal is to restore the app to the state represented by the backup rather than merely importing a few new rows.

### Important backup rule

Before making major changes to the app data, it is recommended to create a **Full Excel Backup**.

Do not edit the IDs or relationship columns in a backup workbook unless you understand the database relationships, because those values are used to reconnect the records during restore.

---

# 14. Database

The application uses **SQLite** through Flutter's `sqflite` package.

The main database tables are:

### Templates

Stores reusable chit-scheme definitions.

Important information includes:

- Scheme name.
- Months.
- Members.
- Installment.
- Due day.
- Maximum payout.

### Groups

Stores individual chit groups created from templates.

### Members

Stores members and their relationship to groups.

### Payments

Stores monthly payment records, including payment status, amount, payment method, and payment date.

### Ledger

Stores financial transactions used by the dashboard and analysis functions.

---

# 15. Database Migration

V3 uses database version 3.

When an older V2 database is opened, the application adds the new `max_payout` field to existing scheme records so the existing database can continue to work.

For older records where a maximum payout was not previously stored, the migration initializes the value using the existing scheme duration and installment. This is a migration default; the operator can edit the scheme afterward and set the intended maximum payout.

Newly created/seeded example scheme data uses a maximum payout of ₹5,00,000 for the 25-month ₹16,000 scheme.

---

# 16. Technology Stack

The application is built with:

- **Flutter** — Android application framework.
- **Dart** — programming language.
- **SQLite / sqflite** — local database.
- **intl** — date and number formatting.
- **url_launcher** — WhatsApp/contact launching.
- **excel** — Excel workbook creation and reading.
- **file_picker** — selecting Excel backup files.
- **share_plus** — sharing/saving generated Excel files through Android's sharing interface.
- **cross_file** — file representation used by sharing.

---

# 17. Project Structure

The repository is intentionally simple so it can be maintained easily from GitHub and built through GitHub Actions.

```text
lakshmi-chit-funds-manager/
│
├── .github/
│   └── workflows/
│       └── build-apk.yml
│
├── main.dart
├── db.dart
├── pubspec.yaml
└── README.md
```

The Flutter build workflow generates the Android project during the GitHub Actions build and then restores the application's source files into the generated Flutter project.

This approach is important because the repository stores the main application source files at the repository root rather than inside the normal Flutter `lib/` directory.

---

# 18. GitHub Actions APK Build

The project is designed to be built using GitHub Actions.

The workflow:

1. Checks out the repository.
2. Temporarily backs up `pubspec.yaml`, `main.dart`, and `db.dart`.
3. Installs the configured Flutter version.
4. Creates the Android Flutter project structure.
5. Restores the application source files into `lib/`.
6. Runs `flutter pub get`.
7. Builds the release APK.
8. Uploads the generated APK as a GitHub Actions artifact.

The generated APK is produced at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

The workflow is designed to avoid the earlier problem where `flutter create` could replace the application's source with Flutter's default Demo Home Page.

---

# 19. Building from a Mobile Phone

The project can be maintained without a local computer by using:

- GitHub repository.
- GitHub Actions.
- Android phone for installing/testing the APK.

Typical workflow:

1. Edit or replace the required source file in GitHub.
2. Commit the change.
3. Open **Actions** in GitHub.
4. Run the APK build workflow.
5. Wait for the workflow to finish.
6. Open the workflow run.
7. Download the APK artifact.
8. Install the APK on the Android phone.
9. Test the changes.
10. If something is wrong, correct the source and build again.

---

# 20. Data Safety and Backup Recommendations

Because the main database is stored locally on the phone, the Excel backup is an important protection against device loss, application-data deletion, or accidental changes.

Recommended practice:

- Create a full backup regularly.
- Keep a copy of the backup outside the phone when appropriate.
- Create a backup before large data edits.
- Create a backup before installing a substantially changed APK.
- Test a backup/restore cycle with non-critical data before relying on it as the only business backup.

The app is not a cloud database, so simply installing the APK on another phone does not automatically transfer the original local database.

---

# 21. Important Notes About Analysis

The financial analysis depends on the transactions that have actually been recorded in the application.

For example:

- A payment that was never entered will not be counted as received.
- A chit payout that was never recorded as a lift/ledger transaction will not be counted as given out.
- Incorrect amounts or dates will affect analysis.

The completed-group profit calculation is therefore a **recorded-transaction calculation**, not an independent audit of the chit business.

---

# 22. Current Scope

The current V3 application includes:

- Reusable chit schemes.
- Multiple chit groups.
- Member management.
- Monthly payment matrix.
- Paid / Partial / Pending status.
- Payment amount and balance.
- Payment method.
- Payment date.
- Chit lift month and amount.
- Remaining scheduled months after lift.
- WhatsApp reminder launcher.
- Monthly / quarterly / yearly analysis.
- Year/group/scheme analysis filters.
- Completed-group profit calculation.
- Scheme maximum payout.
- Excel exports.
- Full Excel backup.
- Full Excel restore.
- Local SQLite storage.

---

# 23. Future Enhancements

Possible future additions can be implemented without changing the core purpose of the application, for example:

- Automated scheduled SMS reminders.
- Automated scheduled WhatsApp reminders where supported by Android and WhatsApp capabilities.
- Automatic overdue reminders after the configured grace period.
- More detailed profit/commission analysis.
- Charts and visual dashboards.
- Search and advanced filtering.
- Member-wise statements.
- Group-wise monthly collection reports.
- Printable receipts.
- Additional backup validation.
- More flexible partial-data import/export.

These are future enhancements and should not be considered part of the currently implemented V3 feature set unless they are added in a later version.

---

# 24. Version

**Application:** Lakshmi Chit Manager  
**Version:** V3 / `1.2.0+3`  
**Platform:** Android  
**Storage:** Local SQLite  
**Primary data exchange:** Excel `.xlsx`  
**Build system:** Flutter + GitHub Actions

---

## 25. Summary

Lakshmi Chit Manager V3 is a local Android chit-fund management application built around five main areas: **Home, Groups, Members, Schemes, and Analysis**.

It supports the complete basic workflow of defining a chit scheme, creating groups, adding members, recording monthly payments, recording chit lifts, monitoring financial activity, analysing completed-group profit, and exporting/backup-restoring the underlying data through Excel.

The application is designed to remain simple enough for mobile-only maintenance while keeping the underlying data structured so that it can be backed up and restored reliably.
