const crypto = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {FieldPath, FieldValue, getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {HttpsError, onCall} = require("firebase-functions/v2/https");

initializeApp();

const db = getFirestore();
const auth = getAuth();
const region = "us-central1";

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }

  const adminDoc = await db.collection("users").doc(request.auth.uid).get();
  if (adminDoc.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "관리자만 사용할 수 있습니다.");
  }
}

exports.createStudentAccount = onCall({region}, async (request) => {
  await requireAdmin(request);

  const name = typeof request.data?.name === "string" ?
    request.data.name.trim() : "";
  const email = typeof request.data?.email === "string" ?
    request.data.email.trim().toLowerCase() : "";

  if (!name || name.length > 80) {
    throw new HttpsError("invalid-argument", "학생 이름을 확인해 주세요.");
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    throw new HttpsError("invalid-argument", "학생 이메일을 확인해 주세요.");
  }

  const password = crypto.randomBytes(18).toString("base64url");
  const user = await auth.createUser({
    email,
    password,
    displayName: name,
  });

  try {
    await db.collection("users").doc(user.uid).set({
      email,
      role: "student",
      name,
      managedStudent: true,
      requirePasswordChange: true,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    try {
      await auth.deleteUser(user.uid);
    } catch (rollbackError) {
      console.error("Could not remove Auth user after profile write failed", {
        uid: user.uid,
        rollbackError,
      });
    }
    throw error;
  }

  return {email, password};
});

exports.completeStudentPasswordChange = onCall({region}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }

  const password = typeof request.data?.password === "string" ?
    request.data.password : "";
  if (password.length < 8 || password.length > 128) {
    throw new HttpsError(
        "invalid-argument",
        "비밀번호는 8자 이상 128자 이하여야 합니다.",
    );
  }

  const userRef = db.collection("users").doc(request.auth.uid);
  const userDoc = await userRef.get();
  if (userDoc.data()?.requirePasswordChange !== true) {
    throw new HttpsError("failed-precondition", "변경이 필요한 계정이 아닙니다.");
  }

  await auth.updateUser(request.auth.uid, {password});
  await userRef.update({requirePasswordChange: false});
  return {changed: true};
});

exports.deleteStudentRosterAndAttendance = onCall({
  region,
  timeoutSeconds: 540,
  memory: "512MiB",
}, async (request) => {
  await requireAdmin(request);

  const studentUid = typeof request.data?.studentUid === "string" ?
    request.data.studentUid.trim() : "";
  if (!studentUid) {
    throw new HttpsError("invalid-argument", "학생 계정을 선택해 주세요.");
  }

  const studentRef = db.collection("users").doc(studentUid);
  const student = await studentRef.get();
  if (student.data()?.role !== "student") {
    throw new HttpsError("not-found", "학생 계정을 찾을 수 없습니다.");
  }

  let batch = db.batch();
  let operationCount = 0;
  const commitIfNeeded = async () => {
    if (operationCount === 0) return;
    await batch.commit();
    batch = db.batch();
    operationCount = 0;
  };
  const queueDelete = async (ref) => {
    batch.delete(ref);
    operationCount++;
    if (operationCount >= 400) await commitIfNeeded();
  };
  const queueUpdate = async (ref, updates) => {
    batch.update(ref, ...updates);
    operationCount++;
    if (operationCount >= 400) await commitIfNeeded();
  };

  const attendance = await db.collection("attendance").get();
  for (const month of attendance.docs) {
    if (month.id.startsWith(`${studentUid}_`)) {
      await queueDelete(month.ref);
      continue;
    }

    const days = await month.ref.collection("days").get();
    for (const day of days.docs) {
      const data = day.data();
      const updates = [];
      for (const field of ["status", "attendees"]) {
        const values = data[field];
        if (values && Object.prototype.hasOwnProperty.call(values, studentUid)) {
          updates.push(new FieldPath(field, studentUid), FieldValue.delete());
        }
      }
      if (updates.length > 0) await queueUpdate(day.ref, updates);
    }
  }

  await queueDelete(studentRef);
  await commitIfNeeded();

  return {deleted: true};
});
