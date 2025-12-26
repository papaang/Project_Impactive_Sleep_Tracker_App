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



### Medication

Track medication intake with detailed information:

- **Medication Type**: Predefined categories like Melatonin, Sertraline, etc.
- **Dosage**: Amount taken (mg)
- **Time**: When the medication was taken

The default dosage if automatically used if it has been defined for that medcation type, otherwise the user will be prompted to type in a dosage.

### Caffeine & Alcohol

Log consumption of substances that may affect sleep:

- **Substance Type**: Coffee or Alcohol
- **Amount**: Number of servings consumed (cups/glasses)
- **Time**: When the substance was consumed

### Exercise

Record physical activity sessions:

- **Exercise Type**: Light, Medium, or Heavy intensity
- **Start Time**: When the exercise began
- **Finish Time**: When the exercise ended

### Notes

Free-form text entries for additional context. These could include:

- Personal observations about the day
- Factors that might affect sleep
- Any other relevant information

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
> To turn off the notification, block notifications from the settings.

## Categories

The app uses dynamic categories to organize different types of data, with default categories:

- **Day Types**: Work, Relax, Travel, Social
- **Sleep Locations**: Bed, Couch, In Transit
- **Medication Types**: Melatonin, Daridorexant, Sertraline, etc.
- *Exercise Types*: Light, Medium, Heavy
- *Substance Types*: Coffee, Alcohol

**Day Types**, **Sleep Locations**, and **Medication Types** (and dosages) are editable from the category manageent screen in the app settings. Users can assign an icon and color to each category to help distinguish them.
