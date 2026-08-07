const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const env = fs.readFileSync(path.join(__dirname, '../../supabase/.env'), 'utf8');
const url = env.match(/SUPABASE_URL=(.*)/)[1].trim();
const key = env.match(/SUPABASE_SERVICE_ROLE_KEY=(.*)/)[1].trim();
const sb = createClient(url, key, {
  auth: { autoRefreshToken: false, persistSession: false },
});

(async () => {
  const { data: list, error: le } = await sb.auth.admin.listUsers({ perPage: 200 });
  if (le) {
    console.error(le);
    process.exit(1);
  }
  const users = list?.users || [];
  console.log('Auth users count:', users.length);
  users.forEach((u) => console.log('-', u.email, u.id));

  let admin = users.find((u) => (u.email || '').toLowerCase() === 'admin@gmail.com');
  if (!admin) {
    const created = await sb.auth.admin.createUser({
      email: 'admin@gmail.com',
      password: '123123',
      email_confirm: true,
      user_metadata: { display_name: 'Admin' },
    });
    if (created.error) {
      console.error('create', created.error);
      process.exit(1);
    }
    admin = created.data.user;
    console.log('Created admin auth', admin.id);
  } else {
    // Ensure password works for factory login
    const updated = await sb.auth.admin.updateUserById(admin.id, {
      password: '123123',
      email_confirm: true,
    });
    if (updated.error) console.error('password update', updated.error);
    else console.log('Admin password reset to 123123');
  }

  const { data, error } = await sb
    .from('users')
    .upsert(
      {
        id: admin.id,
        email: 'admin@gmail.com',
        display_name: 'Admin',
        role: 'admin',
        onboarding_complete: true,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'id' },
    )
    .select();
  console.log(error || data);
})();
