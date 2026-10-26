# Data Safety & Privacy Declarations

**Purpose**: This document provides comprehensive information for completing Google Play Data Safety and iOS App Privacy declarations. All information must be accurate and match actual app behavior.

**Last Updated**: February 6, 2026

---

## Data Collection Summary

### Health & Fitness Data
**Collected**: YES  
**Shared with third parties**: YES (for processing only)  
**User can request deletion**: YES

#### Specific Types:
- Blood test results and biomarker data (uploaded lab reports)
- Health scores and functional grading (10 health domains)
- Disease risk predictions (AI-generated)
- Activity data (if wearable integration implemented)
- Diet and nutrition logs
- Biological age calculations

#### Purpose:
- App functionality (core health analysis)
- Personalization (custom protocols and recommendations)
- AI/ML model processing

---

### Personal Information
**Collected**: YES  
**Shared with third parties**: YES (authentication and backend storage)  
**User can request deletion**: YES

#### Specific Types:
- Name
- Email address
- Date of birth
- Phone number (if provided)
- Profile photo (if uploaded)

#### Purpose:
- Account management
- User authentication
- Communication (notifications, support)
- Personalization

---

### App Activity
**Collected**: YES  
**Shared with third parties**: NO  
**User can request deletion**: YES

#### Specific Types:
- App interactions (screen views, feature usage)
- In-app search history
- Chat conversation history with AI

#### Purpose:
- App functionality
- User experience improvement
- Personalization

---

### Files and Docs
**Collected**: YES  
**Shared with third parties**: YES (for processing)  
**User can request deletion**: YES

#### Specific Types:
- Lab report PDFs
- Images of lab reports
- Photos for meal scanning (Lens feature)

#### Purpose:
- App functionality (lab report processing, meal analysis)
- AI/ML model processing

---

### Device or Other IDs
**Collected**: YES  
**Shared with third parties**: NO  
**User can request deletion**: No (technical requirement)

#### Specific Types:
- Installation ID (Firebase/Flutter)

#### Purpose:
- Analytics
- App functionality
- Fraud prevention and security

---

## Third-Party Data Sharing

### 1. Supabase (Backend & Database)
**Purpose**: Data storage and backend services  
**Data Shared**:
- All user profile data
- All health data
- Authentication information
- Lab reports and health records

**Data Processing Location**: US/EU (depending on server configuration)  
**Retention**: Until user requests deletion or account closure

---

### 2. Azure OpenAI (Microsoft)
**Purpose**: AI-powered health insights and analysis  
**Data Shared**:
- Lab report data (biomarkers, test results)
- Health questionnaire responses
- Anonymized health metrics for analysis

**Data Processing Location**: As per Microsoft Azure regions  
**Retention**: Not stored by OpenAI (processed in real-time per API usage terms)

---

### 3. Google Sign-In
**Purpose**: Authentication  
**Data Shared**:
- Email address
- Name
- Profile photo (if using Google account)

**Data Processing Location**: Google's infrastructure  
**Retention**: As per Google's privacy policy

---

### 4. Google Generative AI (Gemini)
**Purpose**: AI features (daily rhythm generation, chat)  
**Data Shared**:
- Health context for personalized recommendations
- Chat conversation history

**Data Processing Location**: As per Google's infrastructure  
**Retention**: As per Google's privacy policy

---

## Data Security

### Encryption
- **Data in Transit**: All network communication uses HTTPS/TLS encryption
- **Data at Rest**: Health data stored in Supabase is encrypted at rest
- **Authentication**: Secure token-based authentication via Supabase Auth

### Access Control
- Users can only access their own health data
- Role-based access control for admin features
- Secure password requirements

---

## Data Retention & Deletion

### User Rights
- Users can request complete data deletion via app settings
- Users can export their health data
- Account deletion removes all associated data

### Retention Policy
- Active user data: Retained while account is active
- Deleted accounts: Data purged within 30 days
- Backup copies: Purged within 90 days

### How to Request Deletion
1. Navigate to Settings > Account > Delete Account
2. Or email: support@zyndio.example

---

## Permissions Required

### Android (AndroidManifest.xml)

#### INTERNET
**Required**: YES  
**Justification**: Essential for app functionality (data sync, authentication, AI processing)

#### ACCESS_NETWORK_STATE
**Required**: YES  
**Justification**: Check network connectivity before making API calls

#### CAMERA
**Required**: YES  
**Justification**: Scan meals for nutritional analysis in Lens feature. Scan lab reports for upload.

#### RECORD_AUDIO
**Required**: NO  
**Justification**: NOT USED - Should be removed (no voice features implemented)

#### MODIFY_AUDIO_SETTINGS
**Required**: YES  
**Justification**: Adjust audio playback for meditation audio features

---

### iOS (Info.plist)

#### NSCameraUsageDescription
**Current**: "Zyndio uses the camera to scan meals for nutritional analysis in Lens."  
**Improved**: "Zyndio uses your camera to scan meals for nutritional tracking and to capture lab reports for upload and analysis."

#### NSMicrophoneUsageDescription
**Current**: "Zyndio uses the microphone for voice commands during meal logging."  
**Status**: NOT USED - Should be removed

#### NSPhotoLibraryUsageDescription
**Required**: YES (if not already present)  
**Suggested**: "Zyndio needs access to your photo library to select lab reports and meal photos for upload and analysis."

---

## Store Listing Declarations

### Google Play Data Safety - Quick Checklist
- [ ] Health & Fitness: Collected, Shared, Optional
- [ ] Personal Info: Collected, Shared, Required
- [ ] Files: Collected, Shared, Optional
- [ ] Device IDs: Collected, Not Shared, Required
- [ ] All data encrypted in transit
- [ ] User can request deletion
- [ ] Link to Privacy Policy: https://zyndio.example/privacy (or in-app)

### iOS App Privacy - Quick Checklist
- [ ] Health data collected
- [ ] Personal data collected
- [ ] Data linked to user identity
- [ ] Data used for tracking: NO
- [ ] Data used for third-party advertising: NO
- [ ] Link to Privacy Policy: https://zyndio.example/privacy (or in-app)

---

## Important Notes

> [!WARNING]
> **Accuracy is Critical**: Any mismatch between what you declare and what the app actually does can result in rejection or removal from the store.

> [!IMPORTANT]
> **Health Data Scrutiny**: Because this is a health app, expect heightened review. Ensure all health data handling is clearly disclosed.

> [!CAUTION]
> **Third-Party SDKs**: Always review the privacy policies of third-party services (Supabase, Azure, Google) to ensure your declarations are accurate.

---

## Review Before Submission

### Verification Steps:
1. ✅ Review actual data collected in app
2. ✅ Verify all third-party SDK usage
3. ✅ Confirm Privacy Policy matches this document
4. ✅ Test data deletion functionality
5. ✅ Ensure all permissions have proper descriptions
6. ✅ Remove any unused permissions

