# FlowStack iOS example

Open `Example.xcodeproj` and run the `Example` app on an iOS 16 or newer
simulator. The project links FlowStack from this checkout through a local Swift
Package dependency, so it exercises the library sources in the repository.

The sample is a small storefront flow:

- Shop and Saved tabs keep independent navigation stacks.
- Product details use push navigation; the cart opens as a sheet.
- Checkout uses an async sign-in gate. The signed-out path shows a global alert;
  the Sign In button toggles the demo session so the flow can continue.
- Checkout opens a nested address screen, then resets the current tab and
  dismisses its modal flow after the demo order is placed.
- Choose **Single Root** from the navigation bar to switch to a `FlowStackView`
  backed by one `FlowRouter`. Push Details, then choose **Set Root to Profile**
  to replace the root and clear the pushed path; use **Tabs** to return to the
  independent tab stacks.

The cart, sign-in state, and checkout decision are app-owned demo state. The
example does not contact a payment, account, or delivery service.
