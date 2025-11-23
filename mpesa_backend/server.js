const express = require("express");
const axios = require("axios");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

// ✅ Your Daraja credentials
const consumerKey = "XKb9v1b4L4rl8XAzNdopyj6IUsNXklOBP1J3WzGf6kQ6AewJ";
const consumerSecret = "Hpg75V0Y7CSzH97q6bXsTqxBkD4ckTNJZZdlh7V2kfozXY3nXWqOul8WszlMhzsT";
const shortCode = "174379";
const passKey = "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919";

// Encode credentials
const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");

// ✅ Generate Access Token
async function getAccessToken() {
  try {
    const response = await axios.get(
      "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials",
      {
        headers: { Authorization: `Basic ${auth}` },
      }
    );
    console.log("✅ Access Token Generated");
    return response.data.access_token;
  } catch (error) {
    console.error("❌ Access Token Error:", error.response?.data || error.message);
    throw error;
  }
}

// ✅ STK Push Request
app.post("/stkpush", async (req, res) => {
  try {
    const { amount, phone, meter } = req.body;

    // Validate input
    if (!amount || !phone || !meter) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields: amount, phone, meter",
      });
    }

    console.log("📤 STK Push Request:", { amount, phone, meter });

    const token = await getAccessToken();

    // Generate timestamp: YYYYMMDDHHMMSS
    const timestamp = new Date()
      .toISOString()
      .replace(/[^0-9]/g, "")
      .slice(0, 14);

    // Generate password
    const password = Buffer.from(shortCode + passKey + timestamp).toString("base64");

    console.log("🔐 Debug Info:");
    console.log("   Timestamp:", timestamp);
    console.log("   Shortcode:", shortCode);
    console.log("   Password (first 30):", password.substring(0, 30) + "...");

    // STK Push payload
    const payload = {
      BusinessShortCode: shortCode,
      Password: password,
      Timestamp: timestamp,
      TransactionType: "CustomerPayBillOnline",
      Amount: Math.floor(amount),
      PartyA: phone,
      PartyB: shortCode,
      PhoneNumber: phone,
      CallBackURL: "https://cytologically-substructural-raylene.ngrok-free.app/callback",
      AccountReference: meter,
      TransactionDesc: "TokenTosha Payment",
    };

    console.log("📦 Sending payload to M-Pesa...");

    const response = await axios.post(
      "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest",
      payload,
      {
        headers: { Authorization: `Bearer ${token}` },
      }
    );

    console.log("✅ STK Push Success!");
    console.log("Response:", response.data);

    res.status(200).json({
      success: true,
      message: "STK Push sent successfully",
      data: response.data,
    });
  } catch (error) {
    console.error("❌ STK Push Error:", error.response?.data || error.message);
    res.status(500).json({
      success: false,
      message: "Failed to initiate STK Push",
      error: error.response?.data || error.message,
    });
  }
});

// ✅ M-Pesa Callback
app.post("/callback", (req, res) => {
  console.log("📥 M-Pesa Callback Received:");
  console.log(JSON.stringify(req.body, null, 2));

  const result = req.body.Body?.stkCallback;
  if (result) {
    if (result.ResultCode === 0) {
      console.log("✅ Payment Successful!");
      console.log("Amount:", result.CallbackMetadata?.Item?.find(i => i.Name === "Amount")?.Value);
      console.log("Transaction ID:", result.CallbackMetadata?.Item?.find(i => i.Name === "MpesaReceiptNumber")?.Value);
    } else {
      console.log("❌ Payment Failed:", result.ResultDesc);
    }
  }

  res.json({ ResultCode: 0, ResultDesc: "Accepted" });
});

// ✅ Test route
app.get("/", (req, res) => {
  res.send("🚀 TokenTosha M-Pesa Server Running!");
});

// ✅ Health check
app.get("/health", (req, res) => {
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
  });
});

// ✅ Fetch token (for testing)
app.post("/fetchToken", (req, res) => {
  const { phone } = req.body;
  console.log("Fetching token for phone:", phone);
  const token = "TOKEN-" + Math.floor(Math.random() * 100000000);
  res.json({ token });
});

// Start server
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🌍 Server running on http://localhost:${PORT}`);
  console.log(`📱 Ready to receive STK Push requests`);
});
