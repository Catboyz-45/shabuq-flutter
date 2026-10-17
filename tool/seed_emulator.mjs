// Seeds the local Firebase Emulator with demo data. Never touches a real project.
//
//   firebase emulators:start --only auth,firestore
//   node tool/seed_emulator.mjs
//
// Demo accounts (password for all: shabuq-demo):
//   admin@shabuq.test      Super Admin
//   teenoi@shabuq.test     shop admin for "teenoi"
//   customer@shabuq.test   customer without a queue
//   guest1..3@shabuq.test  customers already waiting at teenoi (A001–A003)

const projectId = process.env.FIREBASE_PROJECT ?? 'ftf3-f150b';
const authHost = 'http://127.0.0.1:9099';
const firestoreHost = 'http://127.0.0.1:8080';
const password = 'shabuq-demo';

async function request(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer owner',
      ...options.headers,
    },
  });
  if (!response.ok) {
    throw new Error(`${options.method ?? 'GET'} ${url}: ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

function toValue(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(toValue) } };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === 'number') return { doubleValue: value };
  if (typeof value === 'object') {
    return { mapValue: { fields: toFields(value) } };
  }
  return { stringValue: String(value) };
}

function toFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, toValue(value)]),
  );
}

async function setDoc(path, data) {
  await request(
    `${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/${path}`,
    { method: 'PATCH', body: JSON.stringify({ fields: toFields(data) }) },
  );
}

async function createUser(email) {
  const result = await request(
    `${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`,
    { method: 'POST', body: JSON.stringify({ email, password }) },
  );
  await setDoc(`users/${result.localId}`, { email, createdAt: new Date() });
  return result.localId;
}

// Start from a clean emulator so the script can be re-run.
await request(
  `${firestoreHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
  { method: 'DELETE' },
);
await request(`${authHost}/emulator/v1/projects/${projectId}/accounts`, {
  method: 'DELETE',
});

const now = new Date();
const shops = [
  {
    id: 'teenoi',
    name: 'Teenoi Shabu',
    image: 'assets/images/teenoi.jpg',
    location: 'สยามสแควร์',
    phone: '02-000-0001',
    zones: ['โซน A', 'โซน B'],
    pricePerPerson: 299,
    openingHours: '11:00–22:00 ทุกวัน',
    minutesPerQueue: 6,
  },
  {
    id: 'pho',
    name: 'Pho Shabu',
    image: 'assets/images/pho.jpg',
    location: 'เซ็นทรัลลาดพร้าว',
    phone: '02-000-0002',
    zones: ['ในร้าน', 'ริมหน้าต่าง'],
    pricePerPerson: 359,
    openingHours: '10:00–21:00',
  },
  {
    id: 'wiyaki',
    name: 'Wiyaki',
    image: 'assets/images/wiyaki.jpeg',
    location: 'เมกาบางนา',
    phone: '02-000-0003',
    zones: ['ทั่วไป'],
    pricePerPerson: 399,
    openingHours: '17:00–24:00',
    acceptingQueues: false,
  },
];
for (const { id, ...shop } of shops) {
  await setDoc(`shops/${id}`, {
    acceptingQueues: true,
    ...shop,
    active: true,
    createdAt: now,
    updatedAt: now,
  });
}
// Menu photos come from picsum.photos so the demo shows real image links.
const menu = [
  ['หมูสไลซ์', 'เนื้อสัตว์', 'หมูสันคอสไลซ์บาง', 0, 'https://picsum.photos/seed/shabu-pork/400/300'],
  ['เนื้อวากิว', 'เนื้อสัตว์', 'วากิว A4 ต้องสั่งเพิ่ม', 159, 'https://picsum.photos/seed/shabu-wagyu/400/300'],
  ['ผักรวม', 'ผัก', 'ผักกาดขาว ผักบุ้ง ข้าวโพด', 0, ''],
  ['เห็ดเข็มทอง', 'ผัก', '', 0, ''],
  ['ไอศกรีม', 'ของหวาน', 'วานิลลา ช็อกโกแลต ชาเขียว', 0, 'https://picsum.photos/seed/shabu-icecream/400/300'],
];
for (const [index, [name, category, description, price, imageUrl]] of menu.entries()) {
  await setDoc(`shops/teenoi/menuItems/item${index}`, {
    shopId: 'teenoi',
    shopName: 'Teenoi Shabu',
    name,
    category,
    description,
    price,
    imageUrl,
    active: true,
    createdAt: now,
    updatedAt: now,
  });
}

// Home banners use the promotion images bundled with the app.
const banners = [
  ['assets/images/promotion/teenoi_promotion.jpg', 'โปรโมชั่น Teenoi', 'teenoi'],
  ['assets/images/promotion/pho_promotion.jpeg', 'โปรโมชั่น Pho', 'pho'],
  ['assets/images/promotion/wiyaki_promotion.jpeg', 'โปรโมชั่น Wiyaki', 'wiyaki'],
];
for (const [order, [imageUrl, title, shopId]] of banners.entries()) {
  await setDoc(`banners/banner${order}`, {
    imageUrl,
    title,
    shopId,
    order,
    active: true,
    createdAt: now,
    updatedAt: now,
  });
}

await setDoc('promoCodes/shabu50', {
  code: 'shabu50',
  name: 'ส่วนลด 50 บาท',
  value: 50,
  active: true,
  createdAt: now,
  updatedAt: now,
});

const superAdmin = await createUser('admin@shabuq.test');
await setDoc(`superAdmins/${superAdmin}`, { email: 'admin@shabuq.test' });

const shopAdmin = await createUser('teenoi@shabuq.test');
await setDoc(`admins/${shopAdmin}`, {
  uid: shopAdmin,
  email: 'teenoi@shabuq.test',
  displayName: 'พนักงานร้าน Teenoi',
  active: true,
  shopId: 'teenoi',
  shopName: 'Teenoi Shabu',
  createdAt: now,
  updatedAt: now,
});

await createUser('customer@shabuq.test');

const pad = (number) => String(number).padStart(2, '0');
const today = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;

// Three customers already waiting in zone A, numbered A001–A003.
for (let index = 1; index <= 3; index++) {
  const uid = await createUser(`guest${index}@shabuq.test`);
  const ticketId = `seedticket${index}`;
  const createdAt = new Date(now.getTime() - (10 - index) * 60_000);
  const queueLabel = `A${String(index).padStart(3, '0')}`;
  await setDoc(`queues/${uid}`, {
    userId: uid,
    shopId: 'teenoi',
    shopName: 'Teenoi Shabu',
    zone: 'โซน A',
    zoneCode: 'A',
    partySize: index + 1,
    ticketId,
    queueNumber: index,
    queueLabel,
    walkIn: false,
    customerName: '',
    status: 'waiting',
    createdAt,
  });
  await setDoc(`queueTickets/${ticketId}`, {
    shopId: 'teenoi',
    zone: 'โซน A',
    queueLabel,
    status: 'waiting',
    createdAt,
  });
}
await setDoc('shops/teenoi/queueCounters/A', { date: today, last: 3 });

// A week of closed queues so the shop's statistics have something to show.
// Deterministic pseudo-random numbers keep re-seeding stable.
let seed = 7;
const random = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
const busyHours = [11, 12, 12, 13, 17, 18, 18, 19, 19, 19, 20, 20];
for (let day = 6; day >= 0; day--) {
  const count = day === 0 ? 8 : 10 + Math.floor(random() * 8);
  for (let index = 0; index < count; index++) {
    const date = new Date(now);
    date.setDate(now.getDate() - day);
    date.setHours(busyHours[Math.floor(random() * busyHours.length)], Math.floor(random() * 60), 0, 0);
    if (date > now) date.setTime(now.getTime() - (index + 1) * 20 * 60_000);
    const roll = random();
    const status = roll < 0.8 ? 'completed' : roll < 0.9 ? 'no_show' : 'cancelled';
    const calledAt = new Date(date.getTime() + (5 + Math.floor(random() * 25)) * 60_000);
    const id = `seedhistory-${day}-${index}`;
    await setDoc(`queueHistory/${id}`, {
      userId: '',
      shopId: 'teenoi',
      shopName: 'Teenoi Shabu',
      zone: 'โซน A',
      zoneCode: 'A',
      partySize: 2 + Math.floor(random() * 4),
      ticketId: id,
      queueNumber: index + 1,
      queueLabel: `A${String(index + 1).padStart(3, '0')}`,
      walkIn: true,
      customerName: '',
      status,
      createdAt: date,
      ...(status === 'cancelled' ? {} : { calledAt }),
      queueId: `walkin-${id}`,
      completedAt: new Date(calledAt.getTime() + 60 * 60_000),
      completedBy: shopAdmin,
    });
  }
}

console.log('Seeded emulator for project', projectId);
