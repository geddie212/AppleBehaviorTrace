````markdown
# Apple BehaviorTrace — README / Project TODO

## Project Goal

Apple BehaviorTrace is an iPhone + Apple Watch research prototype inspired by the original BehaviorTrace project.

The objective is to:

- Collect user-labeled emotional or behavioral states through EMA (Ecological Momentary Assessment) prompts.
- Align those labels with Apple Watch and HealthKit biosignal data.
- Train a machine learning model.
- Run predictions locally on Apple devices using Core ML.

### Example Labels

- Tired
- Angry
- Happy
- Stressed
- Craving
- Calm
- Focused

### System Components

1. iPhone app for admin and user EMA workflows.
2. HealthKit export and machine learning pipeline.
3. Apple Watch app for on-device prediction.

---

# 1. Recommended Tech Stack

## Hardware

- Mac with Apple Silicon
- iPhone 15
- Apple Watch Ultra 2

## Development Tools

- Xcode
- SwiftUI
- WatchKit
- HealthKit
- UserNotifications
- Supabase
- Python
- Jupyter Notebook or VS Code
- scikit-learn
- pandas
- numpy
- coremltools
- GitHub

## iPhone App

- SwiftUI
- Supabase Auth
- Supabase Postgres
- HealthKit
- UserNotifications

## Apple Watch App

- SwiftUI
- WatchKit
- HealthKit
- Core ML
- WatchConnectivity

## Backend

### Primary Choice

Supabase

Advantages:

- Authentication included
- PostgreSQL database
- Swift SDK support
- Simple architecture for research projects

### Future Alternatives

- Firebase
- SwiftData
- FastAPI backend

---

# 2. GitHub Repository

## Should This Be Public?

Yes.

This project is suitable for GitHub and can serve as a portfolio project for:

- Apple ecosystem jobs
- Health technology
- Machine learning
- Research software
- Mobile development

## Suggested Repository Structure

```text
AppleBehaviorTrace/
├── README.md
├── ios/
├── watch/
├── backend/
├── ml/
├── docs/
├── database/
├── .gitignore
└── LICENSE
```

## Never Commit

```text
.env
Supabase keys
Apple signing files
Real HealthKit exports
Private user data
Sensitive CSV files
```

Use demo or synthetic datasets instead.

## Good README Sections

- Project Overview
- Screenshots
- Architecture Diagram
- Demo Video
- Tech Stack
- HealthKit Permissions
- ML Pipeline
- Privacy Notes
- Setup Instructions
- Future Roadmap

---

# 3. System Architecture

## Workflow

```text
Admin creates EMA form
        ↓
Admin creates labels and prompt intervals
        ↓
User logs in
        ↓
User sees available labels
        ↓
User starts a state
        ↓
App stores start time
        ↓
EMA notifications are scheduled
        ↓
User confirms or ends state
        ↓
App stores end time
        ↓
HealthKit data is exported
        ↓
Labels and biosignals are aligned
        ↓
Random Forest model is trained
        ↓
Model is converted to Core ML
        ↓
Watch app loads model
        ↓
Watch predicts user state
```

---

# 4. Database Schema

## profiles

```sql
profiles (
  id uuid primary key references auth.users(id),
  email text,
  role text check (role in ('admin', 'user')),
  created_at timestamptz default now()
)
```

---

## forms

```sql
forms (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  created_by uuid references profiles(id),
  created_at timestamptz default now()
)
```

---

## labels

```sql
labels (
  id bigint generated always as identity primary key,
  form_id bigint references forms(id),
  label_name text not null,
  prompt_text text,
  prompt_interval_seconds int not null,
  active boolean default true,
  created_at timestamptz default now()
)
```

Example:

```text
label_name: tired
prompt_text: Are you still feeling tired?
prompt_interval_seconds: 600
```

---

## user_states

```sql
user_states (
  id bigint generated always as identity primary key,
  user_id uuid references profiles(id),
  form_id bigint references forms(id),
  label_id bigint references labels(id),
  started_at timestamptz default now(),
  ended_at timestamptz,
  active boolean default true,
  last_prompted_at timestamptz,
  last_confirmed_at timestamptz
)
```

---

## health_samples

```sql
health_samples (
  id bigint generated always as identity primary key,
  user_id uuid references profiles(id),
  sample_type text not null,
  start_time timestamptz not null,
  end_time timestamptz,
  value double precision,
  unit text,
  source text,
  created_at timestamptz default now()
)
```

Example sample types:

```text
heart_rate
heart_rate_variability
resting_heart_rate
walking_heart_rate_average
respiratory_rate
active_energy
step_count
sleep_analysis
workout
```

---

## ml_windows

```sql
ml_windows (
  id bigint generated always as identity primary key,
  user_id uuid references profiles(id),
  label_id bigint references labels(id),
  window_start timestamptz,
  window_end timestamptz,
  features jsonb,
  label_name text
)
```

---

# 5. iOS App Architecture

Use MVVM.

```text
ios/AppleBehaviorTrace/
├── AppleBehaviorTraceApp.swift
├── Config/
│   ├── SupabaseConfig.swift
│   └── AppConstants.swift
├── Models/
│   ├── Profile.swift
│   ├── EMAForm.swift
│   ├── EMALabel.swift
│   ├── UserState.swift
│   └── HealthSample.swift
├── Services/
│   ├── AuthService.swift
│   ├── FormService.swift
│   ├── LabelService.swift
│   ├── StateSessionService.swift
│   ├── HealthKitService.swift
│   ├── NotificationService.swift
│   └── SupabaseService.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── AdminDashboardViewModel.swift
│   ├── UserDashboardViewModel.swift
│   ├── StateSessionViewModel.swift
│   └── HealthExportViewModel.swift
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Admin/
│   │   ├── AdminDashboardView.swift
│   │   ├── CreateFormView.swift
│   │   └── CreateLabelView.swift
│   ├── User/
│   │   ├── UserDashboardView.swift
│   │   ├── StateButtonView.swift
│   │   └── ActiveStateView.swift
│   └── Shared/
│       ├── LoadingView.swift
│       └── ErrorView.swift
└── Utilities/
    ├── DateUtils.swift
    └── ValidationUtils.swift
```

---

# 6. Main iOS Files

## AuthService.swift

Responsibilities:

- Register
- Login
- Logout
- Fetch current user
- Fetch user role

---

## AuthViewModel.swift

Responsibilities:

- Login state
- Registration state
- Role-based navigation

```text
if role == admin:
    show AdminDashboardView
else:
    show UserDashboardView
```

---

## AdminDashboardView.swift

Features:

- View forms
- Create forms
- Create labels
- Set prompt intervals
- Activate/deactivate labels

---

## CreateFormView.swift

Fields:

- Form title
- Form description

---

## CreateLabelView.swift

Fields:

- Label name
- Prompt text
- Prompt interval

Example:

```text
Label: tired
Prompt: Are you still feeling tired?
Interval: 10 minutes
```

---

## UserDashboardView.swift

Features:

- View labels
- Start state
- View active state
- End state
- Confirm EMA prompts

---

## StateSessionService.swift

Responsibilities:

- Start state
- End state
- Confirm state
- Save timestamps

---

## NotificationService.swift

Responsibilities:

- Request permission
- Schedule notifications
- Cancel notifications
- Reschedule notifications

---

## HealthKitService.swift

Responsibilities:

- Request permissions
- Read HealthKit samples
- Export samples
- Query by date range

---

# 7. Watch App Architecture

```text
watch/AppleBehaviorTraceWatch/
├── AppleBehaviorTraceWatchApp.swift
├── Models/
│   ├── WatchPrediction.swift
│   └── WatchFeatureVector.swift
├── Services/
│   ├── WatchHealthKitService.swift
│   ├── WatchPredictionService.swift
│   └── WatchConnectivityService.swift
├── ViewModels/
│   └── WatchPredictionViewModel.swift
├── Views/
│   ├── PredictionView.swift
│   └── SignalStatusView.swift
└── ML/
    └── BehaviorStateClassifier.mlmodel
```

## WatchHealthKitService.swift

Reads:

- Heart rate
- HRV
- Resting heart rate
- Active energy
- Step count
- Workout data

---

## WatchPredictionService.swift

Responsibilities:

- Load Core ML model
- Build feature vector
- Run prediction
- Return predicted label

---

## PredictionView.swift

```text
Predicted State:
Stressed

Confidence:
72%
```

---

# 8. Machine Learning Pipeline

```text
ml/
├── notebooks/
│   └── exploratory_analysis.ipynb
├── scripts/
│   ├── export_training_data.py
│   ├── build_windows.py
│   ├── extract_features.py
│   ├── train_random_forest.py
│   ├── evaluate_model.py
│   └── convert_to_coreml.py
├── data/
│   ├── raw/
│   ├── processed/
│   └── demo/
├── models/
│   ├── random_forest.pkl
│   └── BehaviorStateClassifier.mlmodel
└── README.md
```

## Step 1 — Export Data

Export:

- user_states
- labels
- health_samples

Output:

```text
data/raw/user_states.csv
data/raw/labels.csv
data/raw/health_samples.csv
```

---

## Step 2 — Build Time Windows

```text
WINDOW_SECONDS = 300
STRIDE_SECONDS = 60
```

Example:

```text
12:00–12:05 = tired
12:01–12:06 = tired
12:02–12:07 = tired
```

---

## Step 3 — Extract Features

Statistics:

```text
mean
std
min
max
range
median
slope
count
last_value
```

Example:

```text
heart_rate_mean
heart_rate_std
heart_rate_min
heart_rate_max
hrv_mean
step_count_sum
active_energy_sum
```

---

## Step 4 — Train Random Forest

```text
RandomForestClassifier
```

Outputs:

```text
models/random_forest.pkl
reports/classification_report.txt
reports/confusion_matrix.png
```

---

## Step 5 — Convert to Core ML

Generate:

```text
BehaviorStateClassifier.mlmodel
```

Add to iPhone and Watch targets.

---

# 9. Python Scripts

## export_training_data.py

- Connect to Supabase
- Export data
- Save CSV files

---

## build_windows.py

- Create fixed windows
- Match HealthKit samples

---

## extract_features.py

- Generate statistical features

---

## train_random_forest.py

- Train classifier
- Save model
- Print metrics

---

## evaluate_model.py

- Confusion matrix
- Per-label accuracy
- Weak label analysis

---

## convert_to_coreml.py

- Convert model
- Save `.mlmodel`

---

# 10. Development Roadmap

## Phase 1 — Basic iPhone App

### TODO

- Create Xcode project
- Add SwiftUI app
- Add Supabase
- Login
- Registration
- Role routing
- Admin dashboard
- User dashboard

Goal:

```text
Admin and user can log in and see different screens.
```

---

## Phase 2 — Admin EMA Builder

### TODO

- Forms table
- Labels table
- CreateFormView
- CreateLabelView
- Prompt intervals
- Save to Supabase

Goal:

```text
Admin can create EMA labels.
```

---

## Phase 3 — User State Logging

### TODO

- View labels
- Start state
- Save started_at
- End state
- Save ended_at

Goal:

```text
User can log behavioral states.
```

---

## Phase 4 — EMA Notifications

### TODO

- Notification permission
- Schedule prompts
- Confirm state
- End state
- Cancel notifications

Goal:

```text
Recurring EMA prompts work correctly.
```

---

## Phase 5 — HealthKit Integration

### TODO

- HealthKit entitlement
- Permissions
- Heart rate
- HRV
- Step count
- Active energy
- Workouts
- Export samples

Goal:

```text
HealthKit data is collected.
```

---

## Phase 6 — Training Dataset

### TODO

- Export data
- Build windows
- Extract features
- Create CSV

Example:

```csv
heart_rate_mean,heart_rate_std,hrv_mean,steps_sum,label
88.2,4.1,42.5,20,tired
```

---

## Phase 7 — Random Forest

### TODO

- Train model
- Evaluate
- Save
- Convert to Core ML

Goal:

```text
Predict user state from biosignals.
```

---

## Phase 8 — Watch App

### TODO

- watchOS target
- HealthKit
- Feature vector
- Load model
- Predict
- Display result

Goal:

```text
Apple Watch predicts user state.
```

---

## Phase 9 — Portfolio Polish

### TODO

- Screenshots
- Architecture diagram
- Demo video
- Sample dataset
- Privacy notes
- Setup guide
- Roadmap
- Limitations

Goal:

```text
Ready for GitHub and job applications.
```

---

# 11. Important Limitations

## HealthKit

Requires explicit user permission.

---

## Apple Watch Sensors

Not all raw sensor streams are available.

Use HealthKit-supported data first.

---

## Real-Time Prediction

Background execution is limited.

Prototype:

```text
Run prediction while the watch app is open.
```

Future:

```text
Investigate background HealthKit updates.
```

---

## Medical Claims

Do not claim medical diagnosis.

Preferred wording:

```text
experimental behavioral state prediction
```

Avoid:

```text
medical diagnosis
```

---

# 12. Suggested README Description

Apple BehaviorTrace is an experimental iOS and watchOS research prototype for collecting EMA state labels and aligning them with Apple Watch biosignal data. Administrators can create custom behavioral prompts, users can log state sessions, and the resulting labels can be paired with HealthKit data to train a machine learning classifier. The trained model can then be converted to Core ML and tested on Apple Watch for on-device behavioral state prediction.

---

# 13. MVP Definition

The first MVP should only include:

```text
1. User/admin login
2. Admin creates labels
3. User views labels
4. User starts and ends a state
5. State timestamps are stored
6. Basic HealthKit heart rate access
7. Python exports labels and HealthKit data
8. Python trains a simple Random Forest model
```

## Important

Do **not** build the watch prediction app first.

Build the data collection and labeling system first, because machine learning models require clean labeled data.
````

