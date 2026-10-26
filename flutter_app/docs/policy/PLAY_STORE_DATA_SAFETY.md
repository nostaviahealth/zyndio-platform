# Google Play Data Safety Guide for Zyndio

This guide helps you fill out the **Data safety** form in the Google Play Console (Policy > App content > Data safety).

## 1. Data Collection and Security
| Question | Answer | Notes |
| :--- | :--- | :--- |
| **Does your app collect or share any of the required user data types?** | **Yes** | |
| **Is all of the user data collected by your app encrypted in transit?** | **Yes** | We use HTTPS/SSL for all network requests (Supabase, APIs). |
| **Do you provide a way for users to request that their data be deleted?** | **Yes** | (Assuming you have a delete account feature or a way to request it via email). |

## 2. Data Types

### **Category: Personal Info**
| Data Type | Collected? | Shared? | Purpose |
| :--- | :--- | :--- | :--- |
| **Name** | Yes | No | App Functionality, Account Management |
| **Email Address** | Yes | No | App Functionality, Account Management |
| **User IDs** | Yes | No | App Functionality, Account Management |
| **Address/Phone** | (Check if applicable) | No | |

### **Category: Health and Fitness**
| Data Type | Collected? | Shared? | Purpose |
| :--- | :--- | :--- | :--- |
| **Health info** | Yes | No* | App Functionality (Tracking health metrics) |
| **Fitness info** | Yes | No* | App Functionality (Workouts, meditation) |
*(Mark "Shared" only if you send this data to a third party that uses it for their own purposes. Sending it to Supabase/Gemini for *your* app's functionality is usually considered "Collected" and "Processed", not "Shared", but check the specific tooltips in the console. Usually, Service Providers don't count as "Sharing" if they only process for you.)*

### **Category: Photos and Videos**
| Data Type | Collected? | Shared? | Purpose |
| :--- | :--- | :--- | :--- |
| **Photos** | Yes | No | App Functionality (Profile pics, food logs, reports) |
| **Videos** | (Check if applicable) | No | |

### **Category: Audio Files**
| Data Type | Collected? | Shared? | Purpose |
| :--- | :--- | :--- | :--- |
| **Voice or Sound Recordings** | Yes | No | App Functionality (If using voice notes) |

### **Category: Files and Docs**
| Data Type | Collected? | Shared? | Purpose |
| :--- | :--- | :--- | :--- |
| **Files and docs** | Yes | No | App Functionality (Medical reports upload) |

### **Category: Device or Other IDs**
| Data Type | Collected? | Shared? | Purpose |
| :--- | :--- | :--- | :--- |
| **Device or other IDs** | Yes | No | App Functionality, Analytics |

## 3. Privacy Policy URL
You will need to host the `PRIVACY_POLICY.md` content on a publicly accessible URL (e.g., your website `zyndio.example/privacy` or a Google Doc/Notion page if you don't have a site primarily).
