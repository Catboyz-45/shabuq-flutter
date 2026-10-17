// Seeds the local Firebase Emulator with demo data. Never touches a real project.
//
//   firebase emulators:start --only auth,firestore
//   node tool/seed_emulator.mjs
//
// Demo accounts (password for all: shabuq-demo):
//   admin@shabuq.test      Super Admin
//   teenoi@shabuq.test     shop admin for "teenoi"
//   customer@shabuq.test   customer without a queue
//   guest1..3@shabuq.test  customers already waiting at teenoi

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
  },
  {
    id: 'pho',
    name: 'Pho Shabu',
    image: 'assets/images/pho.jpg',
    location: 'เซ็นทรัลลาดพร้าว',
    phone: '02-000-0002',
    zones: ['ในร้าน', 'ริมหน้าต่าง'],
    pricePerPerson: 359,
  },
  {
    id: 'wiyaki',
    name: 'Wiyaki',
    image: 'assets/images/wiyaki.jpeg',
    location: 'เมกาบางนา',
    phone: '02-000-0003',
    zones: ['ทั่วไป'],
    pricePerPerson: 399,
  },
];
for (const { id, ...shop } of shops) {
  await setDoc(`shops/${id}`, { ...shop, active: true, createdAt: now, updatedAt: now });
}
const menu = [
  ['หมูสไลซ์', 'เนื้อสัตว์'],
  ['เนื้อวากิว', 'เนื้อสัตว์'],
  ['ผักรวม', 'ผัก'],
  ['เห็ดเข็มทอง', 'ผัก'],
  ['ไอศกรีม', 'ของหวาน'],
];
for (const [index, [name, category]] of menu.entries()) {
  await setDoc(`shops/teenoi/menuItems/item${index}`, {
    shopId: 'teenoi',
    shopName: 'Teenoi Shabu',
    name,
    category,
    active: true,
    createdAt: now,
    updatedAt: now,
  });
}

await setDoc('promoCodes/SHABU50', {
  code: 'SHABU50',
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

for (let index = 1; index <= 3; index++) {
  const uid = await createUser(`guest${index}@shabuq.test`);
  const paymentId = `seedpay${index}`;
  const createdAt = new Date(now.getTime() - (10 - index) * 60_000);
  const partySize = index + 1;
  await setDoc(`payments/${paymentId}`, {
    paymentId,
    userId: uid,
    shopId: 'teenoi',
    shopName: 'Teenoi Shabu',
    partySize,
    pricePerPerson: 299,
    total: partySize * 299,
    coupon: '',
    couponCode: '',
    discount: 0,
    netTotal: partySize * 299,
    payMethod: 'counter',
    createdAt,
  });
  await setDoc(`queues/${uid}`, {
    userId: uid,
    shopId: 'teenoi',
    shopName: 'Teenoi Shabu',
    zone: 'โซน A',
    partySize,
    payMethod: 'counter',
    paymentId,
    status: 'waiting',
    createdAt,
  });
  await setDoc(`queueTickets/${paymentId}`, {
    shopId: 'teenoi',
    zone: 'โซน A',
    status: 'waiting',
    createdAt,
  });
}

console.log('Seeded emulator for project', projectId);
