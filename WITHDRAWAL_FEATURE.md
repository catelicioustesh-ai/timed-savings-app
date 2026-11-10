# M-Pesa Withdrawal Feature Guide

## 🎯 New Features Added

### 1. **PIN Entry Dialog**
- Secure PIN input field (4 digits)
- Shows withdrawal amount and phone number
- PIN is never stored - only used for the transaction
- Security disclaimer included in the dialog

### 2. **Withdrawal Functionality**
- Users can withdraw saved funds directly to their M-Pesa account
- Only available for completed transactions
- Real-time processing with status updates
- Automatic removal from savings after successful withdrawal

### 3. **Backend Withdrawal Endpoint**
- **Endpoint**: `POST /withdraw`
- **Parameters**:
  - `phone`: M-Pesa phone number
  - `amount`: Amount to withdraw
  - `pin`: 4-digit M-Pesa PIN
- **Response**: Withdrawal status and message

## 🔧 Environment Variables Required

Add these to your `.env` file:

```
INITIATE_USERNAME=your_initiate_username_here
SECURITY_CREDENTIAL=your_security_credential_here
```

**How to get these:**
1. Go to M-Pesa Sandbox Portal
2. Navigate to Credentials section
3. Copy the Initiator Name and Security Credential

## 📱 User Flow

1. **Deposit Money**: User sends money via STK push → Status becomes "Completed"
2. **View Savings**: Completed transactions show in the history
3. **Withdraw**: Click "Withdraw" button on completed transactions
4. **Enter PIN**: Dialog appears asking for M-Pesa PIN
5. **Confirmation**: Money is sent back to the phone as B2C payment
6. **Auto-Remove**: Transaction is removed from savings after successful withdrawal

## 🎨 UI Changes

### Transaction Cards
- **Completed Transactions**: 
  - Show green "✓ Completed" status badge
  - Display "Withdraw" button (teal gradient)
  - Keep "Delete" button for manual removal

- **Pending Transactions**:
  - Show orange "⏳ Pending" status badge
  - Only show "Delete" button

- **Failed Transactions**:
  - Show red "✗ Failed" status badge
  - Only show "Delete" button

### New Dialog
- Secure PIN entry field
- Shows withdrawal details
- Security notice: "Your PIN is secure and never stored"
- Formatted with teal theme matching app design

## 🔒 Security Features

✓ **PIN never stored** - Only used for transaction
✓ **PIN not logged** - No records of PIN in backend
✓ **HTTPS only** - Use in production with HTTPS
✓ **Masked input** - PIN field shows dots instead of characters
✓ **Validation** - PIN must be exactly 4 digits

## 🚀 API Integration

### M-Pesa B2C (Business to Customer)

The withdrawal feature uses M-Pesa's B2C API to send money from your business account to customer's M-Pesa wallet.

**Endpoint**: `https://sandbox.safaricom.co.ke/mpesa/b2c/v1/paymentrequest`

**Command ID**: `BusinessPayment`

**Flow**:
1. User initiates withdrawal with PIN
2. Backend validates PIN format (4 digits)
3. Backend gets access token from M-Pesa
4. Backend sends B2C request to M-Pesa
5. M-Pesa processes the transaction
6. Callback updates transaction status
7. App shows real-time confirmation

## 📊 Transaction Types

Now supports 3 transaction types:
1. **Deposit** (STK Push) - User sends money to business
2. **Withdrawal** (B2C) - Business sends money to user
3. **Status Check** - Real-time polling updates

## 💡 Testing Checklist

- [ ] Test deposit works (STK push)
- [ ] Test withdrawal button appears only for completed transactions
- [ ] Test PIN dialog shows correctly
- [ ] Test PIN validation (must be 4 digits)
- [ ] Test withdrawal processing message
- [ ] Test transaction is removed after withdrawal
- [ ] Test multiple withdrawals
- [ ] Test connection indicator shows "Live" during polling

## 📝 Code Structure

### Flutter App (`main.dart`)
- `_showPinDialog()` - Shows PIN entry dialog
- `_processWithdrawal()` - Handles withdrawal API call
- `_buildTransactionCard()` - Updated with withdraw button

### Backend (`server.js`)
- `POST /withdraw` - New withdrawal endpoint
- Uses M-Pesa B2C API
- Stores withdrawal transaction records

## ⚠️ Important Notes

1. **PIN Security**: In production, ensure HTTPS is enabled
2. **B2C Configuration**: Need valid Initiate Username and Security Credential
3. **Testing**: Use Sandbox API credentials for testing
4. **Minimum Amount**: Check with M-Pesa for minimum withdrawal amount
5. **Rate Limits**: M-Pesa may have rate limits on B2C transactions

## 🔄 Real-time Status Updates

Withdrawals also benefit from the existing polling system:
- Status updates every 3 seconds
- Shows "Live" indicator when connected
- Manual refresh button available
- Automatic notifications on completion

---

**Version**: 2.0 (With Withdrawals)
**Last Updated**: 2026-07-07
