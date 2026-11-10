const express = require("express");
const axios = require("axios");
const cors = require("cors");
const admin = require("firebase-admin");
require("dotenv").config();

const app = express();
const deviceTokens = new Set();

const REQUIRED_MPESA_ENV = [
  "CONSUMER_KEY",
  "CONSUMER_SECRET",
  "BUSINESS_SHORTCODE",
  "PASSKEY",
  "CALLBACK_URL",
];

const missingMpesaEnv = REQUIRED_MPESA_ENV.filter(
  (key) => !process.env[key] || process.env[key].trim() === ""
);

if (missingMpesaEnv.length > 0) {
  console.warn(
    `M-Pesa env values missing: ${missingMpesaEnv.join(", ")}. Add them to your .env file before testing live payments.`
  );
}

if (process.env.FIREBASE_PROJECT_ID) {
  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID,
  });
}

function requireMpesaConfig() {
  const missing = REQUIRED_MPESA_ENV.filter(
    (key) => !process.env[key] || process.env[key].trim() === ""
  );

  if (missing.length > 0) {
    throw new Error(
      `Missing M-Pesa config: ${missing.join(", ")}. Add them in your .env file.`
    );
  }
}

app.use(cors());
app.use(express.json());

// In-memory transaction storage
const transactions = new Map();

/* =========================
   BASIC TEST ROUTE
========================= */
app.get("/", (req, res) => {
  res.send("Backend is running");
});

app.get("/config-status", (req, res) => {
  res.json({
    mpesaConfigured: REQUIRED_MPESA_ENV.every(
      (key) => process.env[key] && process.env[key].trim() !== ""
    ),
    missingMpesa: REQUIRED_MPESA_ENV.filter(
      (key) => !process.env[key] || process.env[key].trim() === ""
    ),
    firebaseConfigured: !!process.env.FIREBASE_PROJECT_ID,
  });
});

/* =========================
   GET ACCESS TOKEN
========================= */
async function getAccessToken() {
  requireMpesaConfig();

  const auth = Buffer.from(
    `${process.env.CONSUMER_KEY}:${process.env.CONSUMER_SECRET}`
  ).toString("base64");

  const response = await axios.get(
    "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials",
    {
      headers: {
        Authorization: `Basic ${auth}`,
      },
    }
  );

  return response.data.access_token;
}

/* =========================
   STK PUSH ROUTE
========================= */
app.post("/stkpush", async (req, res) => {
  try {
    requireMpesaConfig();

    const { phone, amount } = req.body;

    const token = await getAccessToken();

    const timestamp = new Date()
      .toISOString()
      .replace(/[-T:.Z]/g, "")
      .slice(0, 14);

    const password = Buffer.from(
      process.env.BUSINESS_SHORTCODE +
        process.env.PASSKEY +
        timestamp
    ).toString("base64");

    const response = await axios.post(
      "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest",
      {
        BusinessShortCode: process.env.BUSINESS_SHORTCODE,
        Password: password,
        Timestamp: timestamp,
        TransactionType: "CustomerPayBillOnline",
        Amount: amount,
        PartyA: phone,
        PartyB: process.env.BUSINESS_SHORTCODE,
        PhoneNumber: phone,
        CallBackURL: process.env.CALLBACK_URL,
        AccountReference: "SavingsApp",
        TransactionDesc: "Saving Money",
      },
      {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }
    );

    // Store transaction in memory
    const checkoutRequestId = response.data.CheckoutRequestID;
    transactions.set(checkoutRequestId, {
      phone,
      amount,
      status: "Pending",
      createdAt: new Date().toISOString(),
      checkoutRequestId,
      resultCode: null,
      resultDesc: null,
      mpesaReceiptNumber: null,
    });

    console.log(`Transaction stored: ${checkoutRequestId}`);

    res.json(response.data);
  } catch (error) {
    res.status(500).json({
      message: "STK Push failed",
      error: error.response?.data || error.message,
    });
  }
});

/* =========================
   CHECK TRANSACTION STATUS
========================= */
app.get("/transaction-status/:checkoutRequestId", (req, res) => {
  const { checkoutRequestId } = req.params;
  const transaction = transactions.get(checkoutRequestId);

  if (!transaction) {
    return res.status(404).json({
      message: "Transaction not found",
    });
  }

  res.json(transaction);
});

/* =========================
   GET ALL TRANSACTIONS
========================= */
app.get("/transactions", (req, res) => {
  const allTransactions = Array.from(transactions.values()).sort(
    (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
  );

  res.json(allTransactions);
});

app.post("/device-token", (req, res) => {
  const { token } = req.body;

  if (!token || typeof token !== "string") {
    return res.status(400).json({ message: "A valid device token is required." });
  }

  deviceTokens.add(token);
  res.json({ success: true, token });
});

app.post("/send-transaction-notification", async (req, res) => {
  const { title, body, token } = req.body;

  if (!admin.apps.length) {
    return res.status(500).json({
      message: "Firebase Admin is not configured. Add FIREBASE_PROJECT_ID and service account credentials.",
    });
  }

  const targetToken = token || [...deviceTokens][0];
  if (!targetToken) {
    return res.status(400).json({
      message: "No device token registered yet. The app must register first.",
    });
  }

  try {
    const message = {
      notification: {
        title: title || "Savings update",
        body: body || "Your transaction status changed.",
      },
      token: targetToken,
    };

    const response = await admin.messaging().send(message);
    res.json({ success: true, messageId: response });
  } catch (error) {
    res.status(500).json({
      message: "Failed to send push notification",
      error: error.message,
    });
  }
});

/* =========================
   CALLBACK URL - M-PESA CONFIRMATION
========================= */
app.post("/callback", (req, res) => {
  console.log("M-Pesa Callback:", JSON.stringify(req.body, null, 2));

  const body = req.body;
  if (body.Body?.stkCallback) {
    const stkCallback = body.Body.stkCallback;
    const checkoutRequestId = stkCallback.CheckoutRequestID;
    const resultCode = stkCallback.ResultCode;
    const resultDesc = stkCallback.ResultDesc;

    // Update transaction status
    if (transactions.has(checkoutRequestId)) {
      const transaction = transactions.get(checkoutRequestId);
      transaction.resultCode = resultCode;
      transaction.resultDesc = resultDesc;
      transaction.status =
        resultCode === 0 ? "Completed" : "Failed";

      // Extract receipt number if successful
      if (resultCode === 0 && stkCallback.CallbackMetadata) {
        const metadata = stkCallback.CallbackMetadata.Item;
        for (let item of metadata) {
          if (item.Name === "MpesaReceiptNumber") {
            transaction.mpesaReceiptNumber = item.Value;
          }
        }
      }

      console.log(`Transaction updated: ${checkoutRequestId} - Status: ${transaction.status}`);
    }
  }

  res.json({ ResultCode: 0, ResultDesc: "Callback accepted" });
});

/* =========================
   START SERVER
========================= */
app.listen(5000, () => {
  console.log("Server running on port 5000");
});

/* =========================
   WITHDRAWAL ROUTE (B2C - Business to Customer)
========================= */
app.post("/withdraw", async (req, res) => {
  try {
    requireMpesaConfig();

    const { phone, amount, pin } = req.body;

    // Validate PIN format (4 digits)
    if (!pin || !/^\d{4}$/.test(pin)) {
      return res.status(400).json({
        message: "Invalid PIN. Must be 4 digits.",
      });
    }

    const token = await getAccessToken();

    const timestamp = new Date()
      .toISOString()
      .replace(/[-T:.Z]/g, "")
      .slice(0, 14);

    // B2C withdrawal request
    const response = await axios.post(
      "https://sandbox.safaricom.co.ke/mpesa/b2c/v1/paymentrequest",
      {
        InitiatorName: process.env.INITIATE_USERNAME,
        SecurityCredential: process.env.SECURITY_CREDENTIAL,
        CommandID: "BusinessPayment",
        Amount: Math.round(amount),
        PartyA: process.env.BUSINESS_SHORTCODE,
        PartyB: phone,
        Remarks: "Savings Withdrawal",
        QueueTimeOutURL: process.env.CALLBACK_URL,
        ResultURL: process.env.CALLBACK_URL,
        Occasion: "Savings",
      },
      {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }
    );

    // Store withdrawal transaction
    const conversationId = response.data.ConversationID;
    transactions.set(conversationId, {
      type: "withdrawal",
      phone,
      amount,
      pin: "****", // Don't store actual PIN
      status: "Pending",
      createdAt: new Date().toISOString(),
      conversationId,
      resultCode: null,
      resultDesc: null,
      mpesaReceiptNumber: null,
    });

    console.log(`Withdrawal initiated: ${conversationId}`);

    res.json({
      ...response.data,
      message: "Withdrawal request sent. Check your phone for confirmation.",
    });
  } catch (error) {
    console.error("Withdrawal error:", error.response?.data || error.message);
    res.status(500).json({
      message: "Withdrawal failed",
      error: error.response?.data || error.message,
    });
  }
});