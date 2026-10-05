# Quick Reference - Role-Based Admin System

## 🚀 Quick Start

### Login as Admin
```
Email: admin@example.com
Password: your_password
→ Click Login
→ Admin Dashboard Web loads automatically
```

### Login as User
```
Email: user@example.com
Password: your_password
→ Click Login
→ Main Navigation loads automatically
```

**Note**: No role selection needed. The system automatically detects your role from the database.

## 📍 Admin Dashboard Sections

| Section | Features |
|---------|----------|
| **Dashboard** | Statistics cards, quick actions |
| **Events** | Add, search, edit, archive, delete events |
| **Members** | Alumni member management (coming soon) |
| **Comments** | Event comments management (coming soon) |
| **Archived** | View archived events |

## 🎮 Admin Dashboard Controls

### Add Event
1. Go to **Events** section
2. Fill the form:
   - Event Theme
   - Batch Year
   - Event Date (click calendar)
   - Venue
3. Click **Add Event**

### Search Events
1. Go to **Events** section
2. Type in search box
3. Results filter in real-time

### Manage Events
1. Go to **Events** section
2. Find event in table
3. Click menu icon (⋮)
4. Select: Edit, Archive, or Delete

### Navigate Sections
- Click sidebar items to switch sections
- Dashboard shows overview
- Each section has specific features

### Logout
- Click **Logout** button in sidebar
- Returns to login screen

## 📊 Dashboard Statistics

- **Total Events**: All events count
- **Active Events**: Currently active
- **Expiring Soon**: Events expiring soon
- **Archived Events**: Previously archived

## 🔐 Authentication Flow

```
Login Screen
  ↓
Enter Email & Password
  ↓
Firebase Authentication
  ↓
Retrieve Role from Firestore
  ↓
Route Based on Role
  ├─ Admin → Admin Dashboard
  └─ User → User Interface
```

## 📁 Key Files

| File | Purpose |
|------|---------|
| `auth_service.dart` | Authentication & role management |
| `admin_dashboard_web.dart` | Admin interface |
| `login_screen.dart` | Login with automatic role detection |

## 🎨 Color Scheme

- **Dark Blue**: #090A4F (primary)
- **Gold**: #FFD700 (accent)
- **Light Blue**: #1A3A52 (secondary)

## ⚡ Features

✅ Role-based login  
✅ Separate admin/user flows  
✅ Professional admin dashboard  
✅ Event management  
✅ Search & filter  
✅ Statistics cards  
✅ Responsive design  

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Admin dashboard not loading | Check Firestore connection |
| Role not saving | Verify Firestore rules |
| Login fails | Check email/password |
| Events not showing | Refresh page |

## 📝 Testing Checklist

- [ ] Admin login works
- [ ] User login works
- [ ] Admin dashboard loads
- [ ] User interface loads
- [ ] Add event works
- [ ] Search works
- [ ] Edit/delete works
- [ ] Logout works

## 🌐 Database

**Firestore Collection**: `users`

```json
{
  "uid": {
    "role": "admin" | "user",
    "createdAt": "timestamp"
  }
}
```

## 💡 Tips

1. **Automatic Role Detection**: System automatically detects your role from database
2. **Search**: Type to filter events instantly
3. **Date Picker**: Click calendar icon for date selection
4. **Sidebar**: Click items to navigate sections
5. **Logout**: Always logout when done

## 🔗 Related Documentation

- `ROLE_BASED_AUTH_GUIDE.md` - Detailed guide
- `IMPLEMENTATION_SUMMARY.md` - Implementation details
- `ADMIN_DASHBOARD_GUIDE.md` - Admin features

---

**Status**: ✅ Ready to Use
