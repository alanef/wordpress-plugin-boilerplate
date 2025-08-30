# Automated Freemius → Public Repo → WordPress.org Deployment Flow

## Overview
This guide explains how to set up an automated deployment pipeline:
1. Private repo deploys to Freemius
2. Freemius deployment triggers sync to public repo
3. Public repo automatically deploys to WordPress.org SVN

## Prerequisites
- Private repository (premium version with Freemius SDK)
- Public repository (free version)
- Freemius account with API credentials
- WordPress.org plugin hosting access

## Setup Instructions

### Step 1: Private Repository Setup

In your **private repository**, modify `.github/workflows/deploy-freemius.yml` to trigger the public repo sync:

```yaml
name: Deploy to Freemius

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    # ... existing Freemius deployment steps ...
    
    - name: Trigger Public Repo Sync
      if: success()
      run: |
        curl -X POST \
          -H "Accept: application/vnd.github+json" \
          -H "Authorization: Bearer ${{ secrets.PUBLIC_REPO_PAT }}" \
          https://api.github.com/repos/YOUR_USERNAME/YOUR_PUBLIC_REPO/dispatches \
          -d '{"event_type":"freemius-deployed","client_payload":{"version":"${{ github.ref_name }}"}}'
```

### Step 2: Public Repository Setup

In your **public repository**, create `.github/workflows/sync-and-deploy.yml`:

```yaml
name: Sync from Freemius and Deploy to WordPress.org

on:
  repository_dispatch:
    types: [freemius-deployed]
  workflow_dispatch:  # Allow manual trigger

jobs:
  sync-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Download Free Version from Freemius
      run: |
        curl -X POST \
          -H "Content-Type: application/json" \
          -d '{"developer_id": "${{ secrets.FREEMIUS_DEV_ID }}", "secret_key": "${{ secrets.FREEMIUS_SECRET_KEY }}"}' \
          https://api.freemius.com/v1/developers/${{ secrets.FREEMIUS_DEV_ID }}/plugins/${{ secrets.FREEMIUS_PLUGIN_ID }}/tags/latest.zip \
          -o free-version.zip
    
    - name: Extract and Update Plugin
      run: |
        unzip -o free-version.zip -d temp-extract
        rsync -av --delete temp-extract/ ./
        rm -rf temp-extract free-version.zip
    
    - name: Commit Changes
      run: |
        git config --local user.email "action@github.com"
        git config --local user.name "GitHub Action"
        git add .
        git commit -m "Sync version ${{ github.event.client_payload.version }} from Freemius" || echo "No changes"
        git push
    
    - name: Deploy to WordPress.org SVN
      run: |
        # Install SVN
        sudo apt-get update
        sudo apt-get install -y subversion
        
        # Checkout SVN repo
        svn co https://plugins.svn.wordpress.org/${{ secrets.WP_PLUGIN_SLUG }} svn-repo
        
        # Copy files to trunk
        rsync -av --exclude='.git' --exclude='.github' --exclude='svn-repo' ./ svn-repo/trunk/
        
        # Add new files
        cd svn-repo
        svn add --force trunk/* --auto-props --parents --depth infinity -q
        
        # Commit to SVN
        svn commit -m "Version ${{ github.event.client_payload.version }}" \
          --username ${{ secrets.SVN_USERNAME }} \
          --password ${{ secrets.SVN_PASSWORD }} \
          --non-interactive
```

### Step 3: Required Secrets Configuration

#### Private Repository Secrets:
- `FREEMIUS_DEV_ID`: Your Freemius Developer ID
- `FREEMIUS_SECRET_KEY`: Your Freemius Secret Key
- `FREEMIUS_PLUGIN_ID`: Your Freemius Plugin ID
- `PUBLIC_REPO_PAT`: Personal Access Token with `repo` scope for triggering public repo workflows

#### Public Repository Secrets:
- `FREEMIUS_DEV_ID`: Your Freemius Developer ID
- `FREEMIUS_SECRET_KEY`: Your Freemius Secret Key
- `FREEMIUS_PLUGIN_ID`: Your Freemius Plugin ID
- `WP_PLUGIN_SLUG`: Your WordPress.org plugin slug
- `SVN_USERNAME`: WordPress.org username
- `SVN_PASSWORD`: WordPress.org password

### Step 4: Create Personal Access Token (PAT)

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Create a new token with `repo` scope
3. Add it as `PUBLIC_REPO_PAT` secret in your private repository

## How It Works

1. **Tag Push**: When you push a tag (e.g., `v1.2.3`) to your private repo
2. **Freemius Deploy**: Private repo deploys to Freemius
3. **Trigger Sync**: On successful deployment, triggers `repository_dispatch` event in public repo
4. **Sync Free Version**: Public repo downloads latest free version from Freemius
5. **Auto Deploy**: Public repo commits changes and deploys to WordPress.org SVN

## Alternative: Using Freemius Webhooks

### Method 1: Using Pipedream (Recommended)

Pipedream acts as a webhook receiver that can trigger GitHub Actions:

1. **Create Pipedream Workflow**:
   - Sign up at https://pipedream.com (free tier available)
   - Create new workflow with HTTP trigger
   - Copy the webhook URL (e.g., `https://eo123abc.m.pipedream.net`)

2. **Configure Pipedream to Trigger GitHub**:
   ```javascript
   // Pipedream workflow step
   import { axios } from "@pipedream/platform"
   
   export default defineComponent({
     props: {
       github_token: {
         type: "string",
         secret: true,
       }
     },
     async run({ steps, $ }) {
       // Parse Freemius webhook data
       const { plugin_id, version, is_premium } = steps.trigger.event.body;
       
       // Only proceed for free version deployments
       if (is_premium) {
         return "Premium version - skipping public repo sync";
       }
       
       // Trigger GitHub Actions
       return await axios($, {
         method: "POST",
         url: "https://api.github.com/repos/YOUR_USERNAME/YOUR_PUBLIC_REPO/dispatches",
         headers: {
           "Authorization": `Bearer ${this.github_token}`,
           "Accept": "application/vnd.github+json",
         },
         data: {
           event_type: "freemius-deployed",
           client_payload: {
             version: version,
             plugin_id: plugin_id
           }
         }
       })
     }
   })
   ```

3. **Configure Freemius Webhook**:
   - Go to Freemius Dashboard → Settings → Webhooks
   - Add new webhook:
     - URL: Your Pipedream webhook URL
     - Events: Select "plugin.version.deployed"
     - Status: Active

### Method 2: Using GitHub's Webhook Endpoint (Direct)

GitHub can receive webhooks directly, but requires payload transformation:

1. **Create GitHub Webhook Receiver Workflow**:
   
   In your public repo, create `.github/workflows/webhook-receiver.yml`:
   ```yaml
   name: Freemius Webhook Receiver
   
   on:
     workflow_dispatch:
       inputs:
         webhook_payload:
           description: 'Freemius webhook payload'
           required: false
   
   jobs:
     process-webhook:
       runs-on: ubuntu-latest
       if: github.event.inputs.webhook_payload != ''
       
       steps:
       - uses: actions/checkout@v3
       
       - name: Parse Webhook Data
         id: parse
         run: |
           echo "${{ github.event.inputs.webhook_payload }}" | base64 -d > payload.json
           VERSION=$(jq -r '.version' payload.json)
           echo "version=$VERSION" >> $GITHUB_OUTPUT
       
       - name: Trigger Sync and Deploy
         run: |
           curl -X POST \
             -H "Accept: application/vnd.github+json" \
             -H "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" \
             https://api.github.com/repos/${{ github.repository }}/dispatches \
             -d '{"event_type":"sync-from-freemius","client_payload":{"version":"${{ steps.parse.outputs.version }}"}}'
   ```

2. **Use Cloudflare Workers as Translator** (free tier available):
   
   Create a Cloudflare Worker to transform Freemius webhook to GitHub format:
   ```javascript
   addEventListener('fetch', event => {
     event.respondWith(handleRequest(event.request))
   })
   
   async function handleRequest(request) {
     if (request.method !== 'POST') {
       return new Response('Method not allowed', { status: 405 })
     }
     
     const freemiusData = await request.json()
     
     // Verify webhook signature (optional but recommended)
     const signature = request.headers.get('X-Freemius-Signature')
     // Add signature verification logic here
     
     // Transform and forward to GitHub
     const githubResponse = await fetch(
       'https://api.github.com/repos/YOUR_USERNAME/YOUR_PUBLIC_REPO/dispatches',
       {
         method: 'POST',
         headers: {
           'Authorization': 'Bearer YOUR_GITHUB_PAT',
           'Accept': 'application/vnd.github+json',
           'Content-Type': 'application/json',
         },
         body: JSON.stringify({
           event_type: 'freemius-webhook',
           client_payload: {
             version: freemiusData.version,
             plugin_id: freemiusData.plugin_id,
             download_url: freemiusData.download_url
           }
         })
       }
     )
     
     return new Response('Webhook processed', { status: 200 })
   }
   ```

### Method 3: Using AWS Lambda (Serverless)

For more control and reliability:

1. **Create Lambda Function**:
   ```python
   import json
   import requests
   import hmac
   import hashlib
   
   def lambda_handler(event, context):
       # Parse Freemius webhook
       body = json.loads(event['body'])
       headers = event['headers']
       
       # Verify webhook signature
       secret = 'YOUR_FREEMIUS_WEBHOOK_SECRET'
       signature = headers.get('X-Freemius-Signature', '')
       
       calculated_sig = hmac.new(
           secret.encode(),
           event['body'].encode(),
           hashlib.sha256
       ).hexdigest()
       
       if signature != calculated_sig:
           return {
               'statusCode': 401,
               'body': json.dumps('Invalid signature')
           }
       
       # Trigger GitHub Actions
       github_token = 'YOUR_GITHUB_PAT'
       response = requests.post(
           'https://api.github.com/repos/YOUR_USERNAME/YOUR_PUBLIC_REPO/dispatches',
           headers={
               'Authorization': f'Bearer {github_token}',
               'Accept': 'application/vnd.github+json'
           },
           json={
               'event_type': 'freemius-deployed',
               'client_payload': {
                   'version': body.get('version'),
                   'plugin_id': body.get('plugin_id')
               }
           }
       )
       
       return {
           'statusCode': 200,
           'body': json.dumps('Webhook processed')
       }
   ```

2. **Configure API Gateway**:
   - Create REST API in AWS API Gateway
   - Create POST method pointing to Lambda
   - Deploy API and get endpoint URL
   - Use this URL in Freemius webhook configuration

### Webhook Security Best Practices

1. **Always verify webhook signatures**:
   ```javascript
   // Example signature verification
   const crypto = require('crypto');
   
   function verifyWebhookSignature(payload, signature, secret) {
     const hash = crypto
       .createHmac('sha256', secret)
       .update(payload)
       .digest('hex');
     
     return hash === signature;
   }
   ```

2. **Whitelist Freemius IPs** (if your receiver supports it):
   - Freemius webhooks come from specific IP ranges
   - Contact Freemius support for current IP list

3. **Add webhook secret in Freemius**:
   - Generate a strong secret key
   - Add it in Freemius webhook configuration
   - Use it to verify signatures in your receiver

### Testing Webhooks

1. **Use RequestBin for testing**:
   - Go to https://requestbin.com
   - Create a new bin
   - Use the URL as temporary webhook endpoint
   - Trigger test webhook from Freemius
   - Inspect the payload structure

2. **Freemius Webhook Tester**:
   - In Freemius Dashboard → Webhooks
   - Click "Test" button next to your webhook
   - Sends sample payload to your endpoint

3. **Local Testing with ngrok**:
   ```bash
   # Install ngrok
   npm install -g ngrok
   
   # Run local webhook receiver
   node webhook-receiver.js
   
   # Expose local server
   ngrok http 3000
   
   # Use ngrok URL in Freemius for testing
   ```

## Manual Fallback

Both workflows support `workflow_dispatch` for manual triggering if automatic flow fails.

## Testing the Flow

1. First test each workflow independently using manual triggers
2. Then test the full automated flow with a test version tag
3. Monitor GitHub Actions logs in both repositories

## Troubleshooting

- Ensure PAT has correct permissions
- Verify all secrets are set correctly
- Check Freemius API credentials are valid
- Confirm WordPress.org SVN credentials work
- Review GitHub Actions logs for specific errors