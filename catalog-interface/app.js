const form = document.getElementById('subscriptionForm');
const summaryContent = document.getElementById('summaryContent');
const payloadPreview = document.getElementById('payloadPreview');
const approvalBoard = document.getElementById('approvalBoard');
const defaultWorkflowUrl = 'https://prod-33.uksouth.logic.azure.com:443/workflows/8c2a077cba674a7d97e15304f0391720/triggers/manual/paths/invoke?api-version=2019-05-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=cH-zY6qaaQ61udmgoAsTDbHqpXtFGEAxXzkyWu3euyE';

const approvalStages = [
  { name: 'Business Owner', status: 'approved' },
  { name: 'Architecture', status: 'approved' },
  { name: 'Security', status: 'pending' },
  { name: 'FinOps', status: 'pending' },
  { name: 'Platform', status: 'pending' },
  { name: 'Terraform Plan', status: 'pending' }
];

const defaultPayload = {
  requestId: 'SUB-VEND-' + Date.now(),
  status: 'Pending approvals',
  requiredApprovals: [
    'Application / Business Owner',
    'Cloud Solutions / Architecture',
    'Security',
    'FinOps',
    'Platform'
  ],
  workflow: 'Request Initiation -> Validation -> Approval -> Subscription Creation -> Management Group Placement -> Final Notification',
  terraformOperation: 'plan',
  lifecycleEvent: 'terraform-completed'
};

function buildPayload(formData) {
  const payload = {
    ...defaultPayload,
    projectName: formData.get('projectName'),
    requestMode: formData.get('requestMode'),
    businessUnit: formData.get('businessUnit'),
    environment: formData.get('environment'),
    businessOwner: formData.get('businessOwner'),
    technicalOwner: formData.get('technicalOwner'),
    subscriptionType: formData.get('subscriptionType'),
    workloadType: formData.get('workloadType'),
    durationDays: Number(formData.get('durationDays') || 30),
    managementGroup: formData.get('managementGroup'),
    region: formData.get('region'),
    dataClassification: formData.get('dataClassification'),
    costCentre: formData.get('costCentre'),
    billingProfile: formData.get('billingProfile') || 'New billing profile required',
    budget: Number(formData.get('budget') || 0),
    budgetCurrency: formData.get('budgetCurrency'),
    networking: formData.get('networking'),
    ipAddress: formData.get('ipAddress'),
    rbac: formData.get('rbac'),
    resourceGroups: formData.get('resourceGroups'),
    tags: formData.get('tags'),
    approvalNotes: formData.get('approvalNotes'),
    cybersecurity: formData.get('cybersecurity'),
    aiUsage: formData.get('aiUsage'),
    customerEmail: formData.get('customerEmail'),
    validationSummary: validateRequest(formData),
    approvalStages,
    createdAt: new Date().toISOString()
  };

  return payload;
}

function validateRequest(formData) {
  const checks = [
    ['Naming', Boolean(formData.get('projectName')?.trim())],
    ['Owner email', Boolean(formData.get('customerEmail')?.includes('@'))],
    ['Budget', Number(formData.get('budget')) > 0],
    ['Management group', Boolean(formData.get('managementGroup'))],
    ['Duration', Number(formData.get('durationDays')) > 0]
  ];
  return checks.map(([name, passed]) => ({ name, status: passed ? 'Passed' : 'Fix required' }));
}

function renderApprovalBoard() {
  approvalBoard.innerHTML = approvalStages
    .map((stage) => `
      <div class="approval-item">
        <span class="label">${stage.name}</span>
        <span class="status ${stage.status}">${stage.status}</span>
      </div>
    `)
    .join('');
}

function renderSummary(payload) {
  const items = [
    ['Project', payload.projectName],
    ['Environment', payload.environment],
    ['Subscription Type', payload.subscriptionType],
    ['Management Group', payload.managementGroup],
    ['Region', payload.region],
    ['Classification', payload.dataClassification],
    ['Owner', payload.businessOwner],
    ['Technical Owner', payload.technicalOwner],
    ['Budget', `${payload.budget} ${payload.budgetCurrency}`],
    ['Billing Profile', payload.billingProfile]
  ];

  summaryContent.innerHTML = items
    .map(([label, value]) => `<div class="summary-item"><strong>${label}</strong><span>${value}</span></div>`)
    .join('');

  payloadPreview.textContent = JSON.stringify(payload, null, 2);
}

function showAlert(message, type = 'success') {
  const existing = document.querySelector('.alert');
  if (existing) existing.remove();

  const alert = document.createElement('div');
  alert.className = `alert ${type}`;
  alert.textContent = message;
  form.appendChild(alert);
}

function submitRequest() {
  const formData = new FormData(form);
  const payload = buildPayload(formData);
  renderSummary(payload);
  renderApprovalBoard();
  showAlert('Request payload generated successfully and is ready for governance review.', 'success');
  return payload;
}

form.addEventListener('submit', (event) => {
  event.preventDefault();
  submitRequest();
});

const downloadJsonBtn = document.getElementById('downloadJsonBtn');
downloadJsonBtn.addEventListener('click', () => {
  const formData = new FormData(form);
  const payload = buildPayload(formData);
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `${payload.projectName.toLowerCase().replace(/\s+/g, '-')}-vending-request.json`;
  anchor.click();
  URL.revokeObjectURL(url);
  showAlert('JSON payload downloaded successfully.', 'success');
});

const sendWorkflowBtn = document.getElementById('sendWorkflowBtn');
sendWorkflowBtn.addEventListener('click', async () => {
  const workflowUrl = localStorage.getItem('logicAppWorkflowUrl') || defaultWorkflowUrl;
  const payload = submitRequest();

  try {
    const response = await fetch(workflowUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    showAlert('Request sent to the Logic App workflow successfully.', 'success');
  } catch (error) {
    showAlert(`Logic App submission failed: ${error.message}`, 'error');
  }
});

const simulateApprovalBtn = document.getElementById('simulateApprovalBtn');
simulateApprovalBtn.addEventListener('click', () => {
  const nextPending = approvalStages.find((stage) => stage.status === 'pending');

  if (!nextPending) {
    showAlert('All approval stages have already been completed.', 'success');
    return;
  }

  nextPending.status = 'approved';
  if (nextPending.name === 'Terraform Plan') {
    defaultPayload.status = 'Approved for Terraform plan';
  }
  renderApprovalBoard();
  showAlert(`${nextPending.name} was approved and the workflow advanced.`, 'success');
});

document.getElementById('resubmitBtn').addEventListener('click', () => {
  defaultPayload.status = 'Pending corrections';
  showAlert('Request marked for correction and resubmission.', 'success');
  renderSummary(buildPayload(new FormData(form)));
});

document.getElementById('rejectBtn').addEventListener('click', () => {
  defaultPayload.status = 'Rejected';
  showAlert('Request marked as rejected and ready for notification.', 'error');
  renderSummary(buildPayload(new FormData(form)));
});

const initialPayload = buildPayload(new FormData(form));
renderSummary(initialPayload);
renderApprovalBoard();
