# CartBuddy Frontend Product Requirements Document (PRD)

## Project Overview
CartBuddy is a collaborative ordering application that allows multiple users to group their orders together to save on delivery fees and other surcharges. A single user can either create a new group order or join an existing one. Payments are held securely by the application until the order is successfully distributed by the creator, verified via an OTP system.

## Tech Stack
- **Framework**: Flutter
- **UI Library**: **Forui** (A beautifully designed UI library for Flutter, saving development time and providing a cohesive look).
- **Routing**: `go_router` for declarative navigation.
- **State Management**: Riverpod
- **API Networking**: Dio
- **Real-time Communication**: Official websocket package (`web_socket_channel`)
- **Payment Gateway**: Razorpay
- **Backend**: Django + PostgreSQL (Separate implementation, currently WIP)

## Core User Flows
1. **Joining an Order**: 
   - User opens the app and sees nearby orders based on locations (e.g., Hostels, Library, Department Building).
   - User selects an order -> Joins -> Pays via Razorpay.
   - Payment is held in escrow by the app.
   - User waits for the creator to receive items.
   - User provides OTP to creator upon receiving their portion.
2. **Creating an Order**: 
   - User creates an order at a specific common point (Hostel, Library, etc.) -> Others join and pay.
   - Creator places the actual order in a third-party app (e.g., Swiggy, Zomato).
   - Creator receives the delivery.
   - Creator distributes items and collects OTPs from joiners.
   - Creator submits OTPs in CartBuddy -> App releases the held funds to the creator's account via Razorpay payouts.

## Frontend Features & Pages

### 1. Authentication (Login, Registration, and Auth Pages)
- **Sign Up**: Register using basic details.
- **Login**: Secure login for returning users.
- **State**: Authentication token management.

### 2. Dashboard / Home Page (Location-Based Discovery)
- Map or List view of active nearby orders categorized by common points (e.g., Hostel A, Library, Department Building).
- Prominent button to "Create a New Order".

### 3. Create an Order Page
- Form to specify order details (e.g., Restaurant name, cutoff time, meetup location like "Library 2nd Floor", max participants).
- Creation generates an active order room.

### 4. Order Room / Chat Room (WebSockets)
- Real-time chat for participants in an active order using `web_socket_channel`.
- List of joined users and their payment/order status.
- Real-time updates on the order lifecycle.

### 5. Profile Page
- View and edit user details (Name, Contact info).
- Manage Razorpay connected accounts / payout methods.

### 6. Previous Orders Page
- History of created and joined orders.
- Status of each order (Completed, Cancelled).
- Summary of amount spent or received.

### 7. Balance and Transactions Page
- View current wallet/escrow balance.
- History of payments made (when joining orders).
- History of payouts received (when creating orders).
- Option to withdraw balance to bank/UPI.

### 8. Order Handover / OTP Flow (Crucial feature)
- **For Joiner**: Secure screen displaying a unique OTP for the active order once it arrives.
- **For Creator**: Input field/scanner to enter OTPs provided by joiners to trigger payout.

### 9. Help Page
- FAQs on how the app works, what to do if an order is wrong, and contact support.

---

## Next Steps
This concludes the planning phase for the PRD. The next steps for implementation will be:
1. Creating a `task.md` to organize the UI screen development.
2. Setting up the Flutter project architecture.
3. Adding the required dependencies (Riverpod, Dio, GoRouter, Forui).