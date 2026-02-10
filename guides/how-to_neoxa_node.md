# Setting Up a New Neoxa Mining VM

This guide will walk you through the steps to set up a new Neoxa mining VM, from creating a new wallet to configuring your mining settings. Follow these steps carefully to ensure a proper setup.

## Step 1: Launch the Neoxa Core Wallet GUI
- **Launch the Neoxa Core Wallet application** on your computer.
  - This will be used to create a new wallet and manage your Neoxa funds.

### Step 2: Create a New Wallet
- **Click "Receive"** to generate a new wallet address.
  - You will need a new address to properly link to your mining node.
- **Enter a name for the new address** (e.g., `neoxa-node-#`).
  - This name helps identify the address used by the specific mining node.
- **Enter 1,000,000** in the amount field.
  - This amount will be used for staking or ensuring proper linkage.
- **Copy the new address** for future use.
  - You will need this address later for mining setup and configuration.

## Step 3: Send a Test Transaction
- **Navigate to "Send"** in the Neoxa Core Wallet GUI.
  - This will allow you to send NEOX to the address you just created.
- **Paste the address** you copied earlier into the recipient field.
  - Double-check the address to avoid any mistakes.
- **Send a test amount** (e.g., `1,000`) to test the connection.
  - **Warning:** If NEOX is sent to the wrong address, **funds are lost forever and cannot be recovered**.
- **Send the amount**.
  - You will be prompted to enter the wallet password.
- After confirming the test funds were correctly sent, **proceed with sending the full 1,000,000 amount** by repeating the prior step but inputting `1,000,000` instead.

## Step 4: Verify the Test Transaction
- **Click "Transactions"** in the GUI.
  - Check if there is a new line stating **"Payment to yourself"**.
  - This confirms that the NEOX test amount was sent correctly.
- After confirming the test funds were correctly sent, **proceed with sending the full 1,000,000 amount** by repeating the prior step but inputting `1,000,000` instead.

## Step 5: Obtain Your Unique Parameters for Smartnode Creation
- **Find your unique Transaction ID** from the GUI by following these steps:
  - Navigate to **"Transactions"** in the Neoxa Core Wallet.
  - **Double-click the most recent transaction** to open its details.
  - Find **"Transaction ID"** in the details window.
  - **Copy the full Transaction ID** as it will be required in the next steps.

- **Check Your Output Index Number**: It is important to determine the output index, which can be either `0` or `1`. Follow these steps to identify it:
  - Go to **"Tools" > "Debug console"** in the Neoxa Core Wallet.
  - Type **`smartnode outputs`** in the console.
  - This command will display the output index for the transaction you made earlier. It will be either `0` or `1`.
  - **Adjust the example command accordingly** in the next step based on your unique output index.

- **Select an Address for Fees**: You will also need to select an address that contains enough NEOX to cover transaction fees. Follow these steps:
  - In the Debug console, use **`listaddressbalances`** to display all addresses with a balance.
  - Choose an address with a sufficient balance for transaction fees (note that an average transaction fee is `0.005` NEOX).
  - If you do not have an address with sufficient balance, **create a new address** labeled **"fees"** and fund it with enough NEOX to cover all your mining fees for a year or more. For instance, funding it with around `1 NEOX` would cover many transactions.

## Step 6: Run ProTx Quick Setup Command
- **Navigate to UI > Tools > Debug console** in the Neoxa Core Wallet to open the console.
- **Enter the modified command** that you customized from the previous steps to generate the necessary `.conf` file for the VM that will serve as the miner node.
  - Example command:
    ```
    protx quick_setup "cfc14de1e1cbe2bf619a6d152a0ade2e4841b6df8817327bbdf8f69e868a553c" "0" "192.168.10.1:8788" "GJ4XMMYGem8AV36yyojdiMfVAp9kEueTmq"
    ```
  - Replace `<transaction_id>`, `<output_index>`, `<public_ip_address>:<port>`, and `<deposit_fee_address>` with your customized values.

- **Collateral index**: This should match the output index (`0` or `1`) determined in the earlier step.
- **Public IP Address Requirement**: The <ip_address> must be a public IP address. If using a VPS, check with your VPS host for the "public IP" and use that. If self-hosting, Google "What's My IP" to find your own public IP. Note: For security reasons, it's best to never share your public IP address with anyone.
- **Fee Address**: This should be any address in your wallet that contains enough Neox to pay the fee (cannot be the address to which you sent the 1 million Neox). When you enter the "protx quick_setup" command, it is considered a transaction and requires a small fee. `0.005` Neox is enough.
  - In the Debug console, use **`listaddressbalances`** to display all addresses with a balance, choose one, and replace the address in the example command that has a sufficient balance.
- **Execute the Command**: Run the **`protx quick_setup`** command within the Debug console. This action will generate a `.conf` file for that specific node in the directory where the wallet is currently located. Open the file and copy its contents for further use.

## Step 7: Spinning Up Your Neoxa Miner VM
- You need a dedicated VM with the specs outlined by [the offical Neoxa Gitbook here](https://neoxa.gitbook.io/documentation/neoxa-documentation/understanding-smartnodes), to function as your NEOX miner. You can self-host it or rent a VPS server, but last I checked the specs were:
  - 2 CPUs
  - 4GB RAM
  - 60GB SSD
- Follow the official [Nexoa Gitbook instructions here](https://neoxa.gitbook.io/documentation/neoxa-documentation/smartnode-setup) to complete your new miner node (note: you can skip the ProTx Command and Setup Wallet Locally sections since these steps were already covered above).

With these steps, your Neoxa Mining VM should be successfully set up and running as a fully configured masternode. Now you get to sit back and watch the NEOX pour in!

![mined_NEOX_proof](https://i.imgur.com/AuI1J0O.png)

## Did I Help You Today?
If my guide helped you, consider sending me whatever NEOX you can spare as thanks.

![NEOX_gratuity](https://i.imgur.com/V9mLtsF.png)

```
Gbv3TnMQoFp1sf7Bfay4r9uQewDVJ5jAQX
```

## Important Note on Running Multiple SELF-HOSTED Nodes
- **Running Multiple Self-Hosted Nodes Behind the Same Public IP**: This generaly (almost exclusively) only applies to self-hosted nodes, but if you are planning to run more than one node behind the same public IP address (especially if you are self-hosting), you will encounter an error when running the ProTx command, stating **"bad-protx-dup-addr (code 18)"**. This error prevents you from creating a second mining node behind the same IP.
  - **Network Provisions**: To avoid this issue, special network provisions must be made, or you must host your second node using a VPS service that provides a different public IP address. While using a VPS is the easiest solution, it may not be the most cost-effective, as hosting costs can exceed the mining profits of the node (e.g., a VPS with 2 cores and 4GB of RAM per month might cost more than the profits of mined NEOX).

## Configuring pfSense for Routing Mining Node Traffic Through VPN (WireGuard or OpenVPN)
If you are self-hosting and want to run more than one Neoxa mining node behind the same public IP address, you will need to use special routing configurations to assign different public IPs to each node. This can be achieved through pfSense using either WireGuard or OpenVPN. Below is a detailed guide on how to achieve this.

### Setting Up pfSense for Mining Node Traffic Routing
1. **Assign a Static IP to the New VM**:
   - In pfSense, assign a static IP address to the newly created VM that will run the self-hosted NEOX mining node.
   - This static IP will be used to identify and route the traffic for this specific VM.

2. **Install WireGuard or OpenVPN Package on pfSense**:
   - Go to **System > Package Manager** in pfSense and install either **WireGuard** or **OpenVPN**.
   - Follow the prompts to complete the installation.

3. **Configure VPN Client**:
   - **WireGuard Configuration**:
     - Set up a **WireGuard client** configuration in pfSense.
     - Enter the **VPN server details** that you are using, such as the public key, endpoint address, and allowed IPs.
     - Assign this WireGuard interface to pfSense and enable it.
   - **OpenVPN Configuration**:
     - Set up an **OpenVPN client** in pfSense with the necessary server details.
     - Ensure the VPN tunnel is properly connected by checking the status in **Status > OpenVPN**.

4. **Set Up Outbound NAT Rules**:
   - Navigate to **Firewall > NAT > Outbound** in pfSense.
   - Set the mode to **Manual Outbound NAT rule generation**.
   - Create a new outbound NAT rule that routes all traffic originating from the static IP of your mining node VM through the WireGuard or OpenVPN tunnel.
   - This ensures that the mining node's traffic uses the public IP address provided by the VPN, bypassing the limitations of the shared public IP.

5. **Firewall Rules for VPN Traffic**:
   - Go to **Firewall > Rules** and add a new rule under the LAN interface.
   - **Source**: Set this to the static IP address of your mining node VM.
   - **Gateway**: Set the gateway to the WireGuard or OpenVPN interface.
   - This rule ensures that all traffic from the mining node VM is directed through the VPN tunnel.

6. **Verify the VPN Connection**:
   - Check the **VPN Status** in pfSense to ensure that the tunnel is active.
   - You can also verify the public IP address of your mining node VM by using a tool like **WhatIsMyIP** from within the VM to confirm it is different from your regular IP.

By following these steps, you can successfully set up multiple Neoxa mining nodes behind the same public IP address by leveraging VPN routing through pfSense. This allows each node to have a unique public IP, preventing conflicts and errors such as **"bad-protx-dup-addr (code 18)"**.

