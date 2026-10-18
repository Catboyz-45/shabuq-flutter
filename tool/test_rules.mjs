// Checks firestore.rules against the Firebase Emulator with real sign-ins.
// Run on freshly seeded data:
//
//   firebase emulators:exec --only auth,firestore \
//     "node tool/seed_emulator.mjs && node tool/test_rules.mjs"
//
// Exits with status 1 if any expectation fails.

const projectId = process.env.FIREBASE_PROJECT ?? 'ftf3-f150b';
const authHost = 'http://127.0.0.1:9099';
const base = `projects/${projectId}/databases/(default)/documents`;
const firestore = `http://127.0.0.1:8080/v1/${base}`;
const password = 'shabuq-demo';

const s = (value) => ({ stringValue: value });
const i = (value) => ({ integerValue: String(value) });
const b = (value) => ({ booleanValue: value });
const now = (...fields) =>
  fields.map((fieldPath) => ({ fieldPath, setToServerValue: 'REQUEST_TIME' }));

const bangkokDate = (date) =>
  new Date(date.getTime() + 7 * 3600_000).toISOString().slice(0, 10);
const today = bangkokDate(new Date());
const yesterday = bangkokDate(new Date(Date.now() - 24 * 3600_000));

async function signIn(email, signUp = false) {
  const action = signUp ? 'signUp' : 'signInWithPassword';
  const response = await fetch(
    `${authHost}/identitytoolkit.googleapis.com/v1/accounts:${action}?key=test`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const body = await response.json();
  return { token: body.idToken, uid: body.localId };
}

const headers = (token) => ({
  Authorization: `Bearer ${token}`,
  'content-type': 'application/json',
});

async function get(token, path) {
  return (await fetch(`${firestore}/${path}`, { headers: headers(token) }))
    .status;
}

async function list(token, collectionId, field, value) {
  const response = await fetch(`${firestore}:runQuery`, {
    method: 'POST',
    headers: headers(token),
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId }],
        where: {
          fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value: s(value) },
        },
      },
    }),
  });
  return response.status;
}

async function commit(token, writes) {
  const response = await fetch(`${firestore}:commit`, {
    method: 'POST',
    headers: headers(token),
    body: JSON.stringify({ writes }),
  });
  return response.status;
}

const doc = (path) => `${base}/${path}`;
const update = (path, fields, transforms = [], mask) => ({
  update: { name: doc(path), fields },
  ...(mask ? { updateMask: { fieldPaths: mask } } : {}),
  ...(transforms.length ? { updateTransforms: transforms } : {}),
});

let failures = 0;
async function expectStatus(name, promise, expected) {
  const actual = await promise;
  const ok = actual === expected;
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name} → ${actual}${ok ? '' : ` (want ${expected})`}`);
}

const customer = await signIn('customer@shabuq.test');
const guest = await signIn('guest1@shabuq.test');
const staff = await signIn('teenoi@shabuq.test');
const superAdmin = await signIn('admin@shabuq.test');
const owner = 'owner';

console.log('— Privacy');
await expectStatus('customer reads another queue', get(customer.token, `queues/${guest.uid}`), 403);
await expectStatus('customer lists a shop\'s queues', list(customer.token, 'queues', 'shopId', 'teenoi'), 403);
await expectStatus('customer lists anonymous tickets', list(customer.token, 'queueTickets', 'shopId', 'teenoi'), 200);
await expectStatus('customer reads shop history', list(customer.token, 'queueHistory', 'shopId', 'teenoi'), 403);
await expectStatus('staff list own shop queues', list(staff.token, 'queues', 'shopId', 'teenoi'), 200);
await expectStatus('staff list another shop', list(staff.token, 'queues', 'shopId', 'pho'), 403);

console.log('— Super Admin');
const impostor = await signIn('admin@gmail.com', true);
await expectStatus('admin@gmail.com gets no admin rights', list(impostor.token, 'admins', 'shopId', 'teenoi'), 403);
await expectStatus('Super Admin lists admins', list(superAdmin.token, 'admins', 'shopId', 'teenoi'), 200);

console.log('— Booking');
const booking = (date, ticketId) => [
  update('shops/pho/queueCounters/A', { date: s(date), last: i(1) }),
  update(
    `queues/${customer.uid}`,
    {
      userId: s(customer.uid), shopId: s('pho'), shopName: s('Pho Shabu'),
      zone: s('ในร้าน'), zoneCode: s('A'), partySize: i(2), ticketId: s(ticketId),
      queueNumber: i(1), queueLabel: s('A001'), queueDate: s(date),
      walkIn: b(false), customerName: s(''), status: s('waiting'),
    },
    now('createdAt'),
  ),
  update(
    `queueTickets/${ticketId}`,
    { shopId: s('pho'), zone: s('ในร้าน'), queueLabel: s('A001'), queueDate: s(date), status: s('waiting') },
    now('createdAt'),
  ),
];
await expectStatus('booking dated yesterday is refused', commit(customer.token, booking(yesterday, 'ruletest1')), 403);
await expectStatus('booking dated today (Bangkok) succeeds', commit(customer.token, booking(today, 'ruletest2')), 200);
await expectStatus('customer bumps a counter alone', commit(customer.token, [update('shops/wiyaki/queueCounters/A', { date: s(today), last: i(1) })]), 403);
await expectStatus('customer calls a queue', commit(customer.token, [update(`queues/${guest.uid}`, { status: s('called') }, [], ['status'])]), 403);

console.log('— Contact on bookings');
const bookAs = (user, ticketId, number, phone) => [
  update('shops/pho/queueCounters/A', { date: s(today), last: i(number) }),
  update(
    `queues/${user.uid}`,
    {
      userId: s(user.uid), shopId: s('pho'), shopName: s('Pho Shabu'),
      zone: s('ในร้าน'), zoneCode: s('A'), partySize: i(2), ticketId: s(ticketId),
      queueNumber: i(number), queueLabel: s(`A00${number}`), queueDate: s(today),
      walkIn: b(false), customerName: s('ลูกค้า'), customerPhone: s(phone),
      status: s('waiting'),
    },
    now('createdAt'),
  ),
  update(
    `queueTickets/${ticketId}`,
    { shopId: s('pho'), zone: s('ในร้าน'), queueLabel: s(`A00${number}`), queueDate: s(today), status: s('waiting') },
    now('createdAt'),
  ),
];
await expectStatus('booking with a script as phone is refused', commit(impostor.token, bookAs(impostor, 'ruletest3', 2, '<script>')), 403);
await expectStatus('booking with a phone number succeeds', commit(impostor.token, bookAs(impostor, 'ruletest4', 2, '081-234-5678')), 200);

console.log('— On the way');
const onTheWay = (token, uid) =>
  commit(token, [update(`queues/${uid}`, {}, now('onTheWayAt'), [])]);
await expectStatus('customer says on the way before being called', onTheWay(guest.token, guest.uid), 403);
await expectStatus('staff call the queue', commit(staff.token, [update(`queues/${guest.uid}`, { status: s('called') }, now('calledAt'), ['status'])]), 200);
await expectStatus('customer says on the way once called', onTheWay(guest.token, guest.uid), 200);
await expectStatus('customer marks someone else on the way', onTheWay(customer.token, guest.uid), 403);
await expectStatus('customer seats themself', commit(guest.token, [update(`queues/${guest.uid}`, { status: s('serving') }, [], ['status'])]), 403);

console.log('— Shops');
const shop = (id) => update(
  `shops/${id}`,
  {
    name: s('ร้านทดสอบ'), location: s(''), phone: s(''), image: s('https://example.com/a.jpg'),
    zones: { arrayValue: { values: [s('ในร้าน')] } }, pricePerPerson: i(349),
    openingHours: s('10:00–20:00'), active: b(true),
  },
  now('createdAt', 'updatedAt'),
);
await expectStatus('Super Admin creates a shop', commit(superAdmin.token, [shop('rule-test-shop')]), 200);
await expectStatus('staff create a shop', commit(staff.token, [shop('rule-other-shop')]), 403);
await expectStatus('shop id with spaces', commit(superAdmin.token, [shop('Bad ID')]), 403);
const shopField = (token, field, value) =>
  commit(token, [update('shops/teenoi', { [field]: value }, now('updatedAt'), [field])]);
await expectStatus('staff set an https image', shopField(staff.token, 'image', s('https://example.com/shop.jpg')), 200);
await expectStatus('staff set a javascript: image', shopField(staff.token, 'image', s('javascript:alert(1)')), 403);
await expectStatus('staff rename the shop', shopField(staff.token, 'name', s('X')), 403);
await expectStatus('customer edits the shop pace', shopField(customer.token, 'minutesPerQueue', { doubleValue: 1 }), 403);

console.log('— Menu, banners, app text');
const menu = (token, shopId, price) => commit(token, [update(
  `shops/${shopId}/menuItems/rule-test`,
  {
    shopId: s(shopId), shopName: s(shopId === 'teenoi' ? 'Teenoi Shabu' : 'Pho Shabu'),
    name: s('x'), category: s('y'), active: b(true), description: s(''),
    imageUrl: s(''), price: i(price),
  },
  now('createdAt', 'updatedAt'),
)]);
await expectStatus('staff add a menu item', menu(staff.token, 'teenoi', 50), 200);
await expectStatus('staff use a negative price', menu(staff.token, 'teenoi', -5), 403);
await expectStatus('staff add to another shop', menu(staff.token, 'pho', 0), 403);
const banner = (token, image) => commit(token, [update(
  'banners/rule-test',
  { imageUrl: s(image), title: s('t'), shopId: s(''), order: i(9), active: b(true) },
  now('createdAt', 'updatedAt'),
)]);
await expectStatus('customer creates a banner', banner(customer.token, 'https://example.com/a.jpg'), 403);
await expectStatus('Super Admin banner with http link', banner(superAdmin.token, 'http://example.com/a.jpg'), 403);
await expectStatus('Super Admin banner with https link', banner(superAdmin.token, 'https://example.com/a.jpg'), 200);
const content = (token, page) =>
  commit(token, [update(`appContent/${page}`, { body: s('x') }, now('updatedAt'))]);
await expectStatus('customer edits help text', content(customer.token, 'help'), 403);
await expectStatus('Super Admin edits help text', content(superAdmin.token, 'help'), 200);
await expectStatus('Super Admin writes an unknown page', content(superAdmin.token, 'other'), 403);

console.log('— Coupons');
await commit(owner, [update(
  `users/${customer.uid}/coupons/shabu50`,
  { code: s('shabu50'), name: s('ส่วนลด 50 บาท'), value: i(50) },
)]);
const code = 'RULE23';
const request = [
  update(
    `couponRedemptions/${code}`,
    {
      userId: s(customer.uid), couponCode: s('shabu50'),
      couponName: s('ส่วนลด 50 บาท'), value: i(50), status: s('pending'),
    },
    now('createdAt'),
  ),
  update(`users/${customer.uid}/coupons/shabu50`, { redemptionCode: s(code) }, [], ['redemptionCode']),
];
await expectStatus('customer requests a redemption code', commit(customer.token, request), 200);
await expectStatus('customer marks the code redeemed', commit(customer.token, [
  update(`couponRedemptions/${code}`, { status: s('redeemed'), redeemedBy: s(customer.uid), shopId: s('teenoi') }, now('redeemedAt'), ['status', 'redeemedBy', 'shopId']),
]), 403);
const redeem = (token) => commit(token, [
  update(`couponRedemptions/${code}`, { status: s('redeemed'), redeemedBy: s(staff.uid), shopId: s('teenoi') }, now('redeemedAt'), ['status', 'redeemedBy', 'shopId']),
  { delete: doc(`users/${customer.uid}/coupons/shabu50`) },
]);
await expectStatus('staff redeem the code', redeem(staff.token), 200);
await expectStatus('staff redeem it twice', redeem(staff.token), 403);
await expectStatus('customer lists redemption codes', list(customer.token, 'couponRedemptions', 'status', 'pending'), 403);

console.log(failures === 0 ? '\nAll rule checks passed.' : `\n${failures} rule check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
