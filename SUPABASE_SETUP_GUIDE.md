# 🗄️ StealthSeal Supabase Setup Guide

Complete SQL commands and RLS policies to recreate your Supabase project from scratch.

---

## 📋 Step 1: Create the `user_security` Table

Run this SQL command in your Supabase SQL Editor:

```sql
-- Create user_security table
CREATE TABLE user_security (
  id UUID PRIMARY KEY,
  real_pin TEXT NOT NULL,
  decoy_pin TEXT NOT NULL,
  biometric_enabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for faster queries
CREATE INDEX idx_user_security_id ON user_security(id);
CREATE INDEX idx_user_security_created_at ON user_security(created_at DESC);
```

### Table Schema Explanation
| Column | Type | Purpose |
|--------|------|---------|
| `id` | UUID | Unique user identifier (primary key) |
| `real_pin` | TEXT | Real PIN to unlock true dashboard |
| `decoy_pin` | TEXT | Decoy PIN to unlock fake dashboard |
| `biometric_enabled` | BOOLEAN | Whether user registered biometric authentication |
| `created_at` | TIMESTAMP | Account creation timestamp |
| `updated_at` | TIMESTAMP | Last update timestamp |

---

## � Step 2: Complete SQL Script (All-in-One)

If you prefer to run everything at once, use this complete script:

```sql
-- ====================================
-- StealthSeal - Complete Supabase Setup
-- ====================================

-- 1. Create user_security table
CREATE TABLE IF NOT EXISTS user_security (
  id UUID PRIMARY KEY,
  real_pin TEXT NOT NULL,
  decoy_pin TEXT NOT NULL,
  biometric_enabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_security_id ON user_security(id);
CREATE INDEX IF NOT EXISTS idx_user_security_created_at ON user_security(created_at DESC);
```

---

## ✅ Step 3: Verification Checklist

Run these queries to verify your setup is correct:

### Check table exists and has correct schema:
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_security'
ORDER BY ordinal_position;
```

### Check indexes are created:
```sql
SELECT indexname, tablename
FROM pg_indexes
WHERE tablename = 'user_security';
```

Expected: 2 indexes shown

---

## 🔧 Step 4: Testing the Setup

After running the SQL commands, test with your Flutter app:

### Test 1: User Registration
```
1. Start app → Splash screen
2. Setup screen → Enter real PIN (e.g., "1234")
3. Confirm real PIN
4. Enter decoy PIN (e.g., "5678")
5. Confirm decoy PIN
6. ✅ App should navigate to Biometric Setup Screen
7. ✅ Check Supabase: New record in user_security table
```

### Test 2: Read PIN Data (Lock Screen)
```
1. Restart app
2. Lock screen loads
3. ✅ PIN entry should work (read from database)
4. Enter correct PIN → unlock app
```

### Test 3: Update Biometric Flag
```
1. In Settings screen
2. Toggle "Enable Biometric"
3. ✅ Supabase biometric_enabled should update to true/false
```

---

## 🚨 Troubleshooting

### Issue: "Row not found" when loading PIN
**Solution**: Ensure user record exists in user_security table. Check app is using correct user ID.

### Issue: "Biometric toggle not updating"
**Solution**: Verify `biometric_enabled` column exists in table. Check database connection.

### Issue: "Insert failed during registration"
**Solution**: Ensure database connection is working. Check user ID being inserted is unique.

---

## 📊 Database Performance Notes

- Indexes on `id` and `created_at` improve query speed
- RLS policies add minimal overhead for user-owned data
- User record is typically small (< 1KB per user)
- Suitable for production use

---

## 🔄 Backup & Recovery

### Export data:
```sql
SELECT * FROM user_security;
```

### Backup before major changes:
```sql
-- Create backup table
CREATE TABLE user_security_backup AS TABLE user_security;
```

---

## 📚 Related Documentation

- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [Supabase SQL Reference](https://supabase.com/docs/guides/database/postgresql)
- [StealthSeal Architecture Guide](./ARCHITECTURE_DIAGRAM.md)
- [Biometric Setup Guide](./BIOMETRIC_SETUP_GUIDE.md)

---

## ✨ Next Steps

After setting up Supabase:

1. ✅ Run the SQL commands above
2. ✅ Verify table and indexes are created
3. ✅ Update your Supabase credentials in `lib/main.dart`
4. ✅ Run `flutter pub get`
5. ✅ Test with `flutter run`
6. ✅ Go through complete user flow (Setup → Biometric → Lock)

---

**Last Updated**: February 26, 2026  
**Version**: 1.0
