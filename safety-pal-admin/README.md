# Safety-Pal Admin Panel

A comprehensive admin dashboard for moderating incident reports, managing safe zones, and configuring system settings for the Women Safety application.

## Features

- **Incident Moderation**: Review, approve, or reject reported incidents with severity assessment
- **Status Tracking**: View incidents by status (pending, validated, rejected)
- **Dashboard**: Real-time statistics and analytics for incident trends
- **Safe Zones Management**: Create and manage community safe zones (shelters, police stations, hospitals)
- **System Settings**: Configure community parameters (radius, risk decay, alert thresholds)
- **Activity Logging**: Track all admin actions for audit purposes

## Tech Stack

- **Framework**: Next.js 16.1.6 (App Router)
- **Styling**: Tailwind CSS + Custom CSS
- **Database**: Firebase Firestore (client-side)
- **Language**: TypeScript

## Prerequisites

- Node.js 18+ and npm
- Firebase project with Firestore enabled
- Firebase configuration credentials

## Environment Setup

1. Clone the repository:

```bash
git clone <repository-url>
cd safety-pal-admin
```

2. Install dependencies:

```bash
npm install
```

3. Create a `.env.local` file in the root directory and add your Firebase configuration:

```
NEXT_PUBLIC_FIREBASE_API_KEY=your_api_key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your_project_id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your_project.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
NEXT_PUBLIC_FIREBASE_APP_ID=your_app_id
```

4. Start the development server:

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to view the application.

## Firestore Collections

### incident_reports

Stores all reported incidents with moderation status

- `id`: Document ID
- `status`: "pending" | "validated" | "rejected"
- `severity`: 1-5 integer rating
- `incidentType`: Type of incident (harassment, assault, threat, etc.)
- `location`: GeoPoint with latitude/longitude
- `images`: Array of image URLs
- `submittedAt`: Timestamp
- `validatedAt`: Timestamp (when approved)
- `rejectionReason`: String (when rejected)

### safe_zones

Community safe locations

- `id`: Document ID
- `name`: Zone name
- `type`: "shelter" | "police" | "hospital" | "community"
- `contact`: Contact information
- `location`: Object with latitude/longitude
- `active`: Boolean flag
- `createdAt`: Timestamp

### system_settings

Global configuration document at path `system_settings/global`

- `community_radius`: Radius in km for incident clustering
- `risk_decay_days`: Days for incident risk to decay
- `min_severity_alert_threshold`: Minimum severity (1-5) to trigger alerts

### admin_activity_logs

Audit log of admin actions

- `adminUid`: ID of admin who performed action
- `actionType`: "approve" | "reject" | "create_zone" | "update_zone" | "delete_zone" | "update_settings"
- `targetId`: ID of targeted resource
- `timestamp`: When action occurred
- `details`: Additional action metadata

## Usage

### Moderating Incidents

1. Navigate to **Incidents** page
2. Select status tab (Pending/Validated/Rejected)
3. For pending incidents:
   - Adjust severity rating (1-5)
   - View incident images and location on map
   - Click **Approve** to validate or **Reject** with reason
4. View validated/rejected incidents in respective tabs

### Managing Safe Zones

1. Navigate to **Safe Zones** page
2. **Create**: Fill form and click "Add Zone"
3. **Toggle**: Click inactive/active badge to enable/disable
4. **Delete**: Click delete button (soft delete)

### Configuring Settings

1. Navigate to **Settings** page
2. Update parameters:
   - Community Radius: Detection distance for incident clustering
   - Risk Decay Days: How long incidents remain in risk calculations
   - Alert Threshold: Minimum severity to trigger notifications
3. Click **Save** to persist changes

## Development

Build the project:

```bash
npm run build
```

Run tests (when available):

```bash
npm test
```

## Deployment

### Vercel (Recommended)

1. Push code to GitHub
2. Import project in Vercel dashboard
3. Add environment variables
4. Deploy automatically on push

### Other Platforms

Ensure Node.js 18+ and the following commands work:

```bash
npm install
npm run build
npm start
```

## Security Notes

- No user authentication required (internal tool)
- Direct Firestore client-side access
- All admin actions logged in `admin_activity_logs`
- Consider implementing security rules before production deployment

## File Structure

```
├── app/
│   ├── incidents/          # Incident moderation UI
│   ├── safe-zones/         # Safe zones management
│   ├── settings/           # System settings
│   ├── layout.tsx          # Root layout with sidebar
│   ├── page.tsx            # Dashboard
│   └── globals.css         # Global styles
├── lib/
│   ├── firebaseClient.ts   # Firebase client initialization
├── types/
│   └── incident.ts         # TypeScript incident types
└── public/                 # Static assets
```

## Troubleshooting

### "Firebase not initialized"

- Check `.env.local` has all required variables
- Restart dev server after adding environment variables

### Incidents not loading

- Verify Firestore has `incident_reports` collection
- Check browser console for Firestore permission errors
- Ensure status filter matches document values (lowercase: "pending", "validated", "rejected")

### Timestamps showing as objects

- Firestore Timestamps are auto-converted by the `.toDate()` utility function
- Verify `toDate()` helper is called on timestamp fields in UI

## Future Enhancements

- [ ] Backend pagination for large datasets
- [ ] Advanced filtering and search
- [ ] Data export/reporting
- [ ] Firestore security rules
- [ ] Unit and E2E tests
- [ ] User authentication for multi-admin teams

## License

Proprietary - Women Safety Initiative

## Support

For issues or questions, contact the development team.
