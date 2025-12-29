# Data Management

The data management features allow users to import, export, and manage their sleep tracking data for backup, analysis, or migration purposes.

- [Data Export](#data-export)
- [Data Import](#data-import)
- [Privacy and Security](#privacy-and-security)
- [Data Structure](#data-structure)

## Data Export

Users can export their sleep data as a ZIP file containing multiple CSV files and a README for:

- Backup purposes
- External analysis in tools like Excel, R, SQL, or PowerBI
- Sharing with healthcare providers
- Archiving historical data

The export includes a timestamped ZIP file that can be shared directly from the app.

## Data Import

The app supports importing individual CSV log files and user categories, enabling:

- Restoring from backups
- Migrating data between devices
- Combining data from multiple sources

The import function automatically deduplicates entries.

## Privacy and Security

All data is stored locally on the device. Users can choose to encrypt or password-protect their export files for secure sharing.

## Data Structure

### Files

- `main_daily_log.csv`: Summary statistics for each day, including total sleep, average latency, awakenings, and summary logs.
- `category_logs/`: Detailed logs for each category.
  - `sleep_log.csv`: Individual sleep sessions with times and metrics.
  - `substance_log.csv`: Caffeine and alcohol consumption entries.
  - `medication_log.csv`: Medication intake entries.
  - `exercise_log.csv`: Exercise session entries.
- `user_categories/`: Definitions of user-defined categories.
  - `day_types.csv`: Day type categories.
  - `sleep_locations.csv`: Sleep location categories.
  - `medication_types.csv`: Medication type categories.
  - `exercise_types.csv`: Exercise type categories.
  - `substance_types.csv`: Substance type categories.

### Column Descriptions

#### main_daily_log.csv
- **Date**: The date of the log entry in YYYY-MM-DD format.
- **Day Type**: The type of day (e.g., Work, Relax, Travel, Social), based on user-selected category.
- **Total Sleep (Hours)**: Total hours of sleep for the day, calculated as the sum of all sleep session durations.
- **Sleep Latency (Mins)**: Average time in minutes taken to fall asleep across all sleep sessions (truncated to integer).
- **Awakenings (Count)**: Total number of awakenings during sleep across all sessions (self-reported).
- **Awake Duration (Mins)**: Overall duration of awakenings during sleep periods across all sessions (self-reported).
- **Out Of Bed Time**: The time the user got out of bed for the last sleep session, in HH:mm format (empty if not recorded).
- **Sleep Sessions Total**: The number of sleep sessions logged for the day.
- **Notes**: Any additional notes entered by the user for the day.
- **Caffeine Total (Cups)**: Total number of cups of coffee (or other caffeine/alcohol) consumed.
- **Meds Log Total (Entries)**: Total number of medication entries for the day.
- **Exercise Total (Mins)**: Total minutes spent exercising for the day.

#### sleep_log.csv
- **Date**: The date of the sleep session in YYYY-MM-DD format.
- **Bed Time**: The time the user went to bed, in HH:mm format.
- **Fell Asleep Time**: The time the user fell asleep, in HH:mm format.
- **Wake Time**: The time the user woke up, in HH:mm format.
- **Out Of Bed Time**: The time the user got out of bed (i.e. Rise Time), in HH:mm format (empty if not recorded).
- **Duration Hours**: The duration of the sleep session in hours (calculated from fell asleep to wake time).
- **Sleep Latency Mins**: Time in minutes taken to fall asleep (bed time to fell asleep time).
- **Awakenings Count**: Number of times the user woke up during this session (self-reported).
- **Awake Duration Mins**: Overall duration of awakenings during this sleep session (self-reported).
- **Sleep Location**: The location where the user slept (e.g., Bed, Couch, In Transit).

#### substance_log.csv
- **Date**: The date of the substance entry in YYYY-MM-DD format.
- **Substance Type**: The type of substance (e.g., caffeine, alcohol).
- **Amount**: The amount consumed (number of cups).
- **Time**: The time the substance was consumed, in HH:mm format.

#### medication_log.csv
- **Date**: The date of the medication entry in YYYY-MM-DD format.
- **Medication Type**: The type of medication taken (e.g., Melatonin).
- **Dosage**: The dosage amount (mg).
- **Time**: The time the medication was taken, in HH:mm format.

#### exercise_log.csv
- **Date**: The date of the exercise session in YYYY-MM-DD format.
- **Exercise Type**: The type of exercise (e.g., Light, Medium, Heavy).
- **Start Time**: The start time of the exercise session, in HH:mm format.
- **Finish Time**: The finish time of the exercise session, in HH:mm format.
- **Duration Mins**: The duration of the exercise session in minutes.

### Notes

- All times are in 24-hour format (HH:mm).
- Dates are in YYYY-MM-DD format. Please use dates to link files for database analysis.
- Durations are in hours or minutes as specified.
- Empty fields indicate no data or N/A.
- Categories (day types, sleep locations, medication types, exercise types, substance types) are editable within the app.

> [!TIP]
> Users can export their sleep log data to a database management system and link it to health logs from other apps (e.g. step tracking or period tracking) using the "Date" column.
