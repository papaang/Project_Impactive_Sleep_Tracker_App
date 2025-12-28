# Daily Activity Logging

The daily activity logging feature allows users to track various aspects of their daily routines and habits that may impact sleep patterns, providing comprehensive context for sleep data analysis.

- [Entry Types](#entry-types)
  - [Sleep Sessions](#sleep-sessions)
  - [Medication](#medication)
  - [Caffeine \& Alcohol](#caffeine--alcohol)
  - [Exercise](#exercise)
  - [Notes](#notes)
  - [Day Type](#day-type)
- [Notification Service](#notification-service)
- [Categories](#categories)

<details>
  <summary>"Event" screen</summary>
  <div class="image-container">
    <img src="../media/events.jpg" width="300">
  </div>
</details>

## Entry Types

### Sleep Sessions

In addition to real-time sleep tracking from the main landing page, sleep sessions can also be added from the events page:

- **Bed Time**: When the user goes to bed
- **Fell Asleep Time**: When the user actually falls asleep
- **Wake Time**: When the user wakes up
- **Out of Bed Time**: When the user gets out of bed
- **Awakenings**: Number of times the user woke up during the night (self-reported)
- **Awake Duration**: Total time spent awake during the awakenings (self-reported)
- **Sleep Location**: Where the user slept (Bed, Couch, In Transit...)

Sleep sessions feature an interactive visual editor with a circular clock interface for intuitive time setting and editing.

<details>
  <summary>"Add Sleep Session" screen 1: Set Times</summary>
  <div class="image-container">
    <img src="../media/add_sleep_session_1.jpg" width="300">
  </div>
</details>
<details>
  <summary>"Add Sleep Session" screen 2: Session Details</summary>
  <div class="image-container">
    <img src="../media/add_sleep_session_2.jpg" width="300">
  </div>
</details>

### Medication

Track medication intake with detailed information:

- **Medication Type**: Predefined categories like Melatonin, Sertraline, etc.
- **Dosage**: Amount taken (mg)
- **Time**: When the medication was taken

The default dosage if automatically used if it has been defined for that medcation type, otherwise the user will be prompted to type in a dosage.

Click a past log entry to edit it.

<details>
  <summary>"Add Medication" screen</summary>
  <div class="image-container">
    <img src="../media/add_medication.jpg" width="300">
  </div>
</details>

### Caffeine & Alcohol

Log consumption of substances that may affect sleep:

- **Substance Type**: Coffee or Alcohol
- **Amount**: Number of servings consumed (cups/glasses)
- **Time**: When the substance was consumed

Click a past log entry to edit it.

<details>
  <summary>"Caffeine & Alcohol" screen</summary>
  <div class="image-container">
    <img src="../media/caffeine_alcohol.jpg" width="300">
  </div>
</details>

### Exercise

Record physical activity sessions:

- **Exercise Type**: Light, Medium, or Heavy intensity
- **Start Time**: When the exercise began
- **Finish Time**: When the exercise ended

Click a past log entry to edit it.

<details>
  <summary>"Exercise" screen</summary>
  <div class="image-container">
    <img src="../media/exercise.jpg" width="300">
  </div>
</details>

### Notes

Free-form text entries for additional context. These could include:

- Personal observations about the day
- Factors that might affect sleep
- Any other relevant information

Notes automatically save after clicking the "Back" button.

### Day Type

Categorize the overall nature of the day. Default day types:

- **Work**: Work or productive days
- **Relax**: Rest or leisure days
- **Travel**: Days involving travel
- **Social**: Days focused on social activities

> [!TIP]
> Long-press on a selected day type to reset it.

## Notification Service

The mobile notification allow easy access to
- The app home screen (by clicking on the notification)
- Quick Action: new Medication entry
- Quick Action: new Caffeine entry
- Quick Action: new Exercise entry

> [!TIP]
> Notifications can be turned off from the app's [settings page](/documentation/features/1_user_interface_md#settings-screen).

<details>
  <summary>Mobile notification</summary>
  <div class="image-container">
    <img src="../media/notification.jpg" width="300">
  </div>
</details>

## Categories

The app uses dynamic categories to organize different types of data, with default categories:

- **Day Types**: Work, Relax, Travel, Social
- **Sleep Locations**: Bed, Couch, In Transit
- **Medication Types**: Melatonin, Daridorexant, Sertraline, etc.
- **Exercise Types**: Light, Medium, Heavy
- **Substance Types**: Coffee, Alcohol

Categories are editable from the category management screen in the app settings. Users can assign an icon and color to each category to help distinguish them.

> [!TIP]
> Press the reset button on the top right of the "Category Management" screen to reset all categories to their default options.

<details>
  <summary>"Category Management" screen</summary>
  <div class="image-container">
    <img src="../media/manage_categories.jpg" width="300">
  </div>
</details>

  - <details>
      <summary>"Add Category" dialog</summary>
      <div class="image-container">
        <img src="../media/add_category.jpg" width="300">
      </div>
    </details>
  - <details>
      <summary>"Edit Category" dialog</summary>
      <div class="image-container">
        <img src="../media/edit_category.jpg" width="300">
      </div>
    </details>
