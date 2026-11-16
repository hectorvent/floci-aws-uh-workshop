// Links shown as QR codes. Change WORKSHOP_URL once the workshop repo is published.
const LINKS = {
  workshop: 'https://github.com/hectorvent/floci-aws-uh-workshop',
  floci: 'https://floci.io',
  github: 'https://github.com/hectorvent',
};

function renderQrCodes() {
  document.querySelectorAll('[data-qr]').forEach((el) => {
    const qr = qrcode(0, 'M');
    qr.addData(LINKS[el.dataset.qr]);
    qr.make();
    el.innerHTML = qr.createSvgTag({ cellSize: 4, margin: 0, scalable: true });
  });
  document.querySelectorAll('[data-qr-label]').forEach((el) => {
    el.textContent = LINKS[el.dataset.qrLabel].replace(/^https?:\/\//, '');
  });
}

// "Twelve attempts": an illustrative agent run against a real account.
// Each attempt is [log lines, minutes waited, dollars spent].
const ATTEMPTS = [
  [['$ terraform apply -auto-approve', 'aws_eks_cluster.main: Still creating... [11m20s elapsed]', '<err>Error: creating EKS Node Group: InvalidParameterException: Subnets are not tagged</err>', '<agent>agent: adding kubernetes.io/role/elb tags to subnets</agent>'], 14, 0.9],
  [['$ terraform apply -auto-approve', '<err>Error: creating RDS DB Instance: InvalidParameterCombination: storage type gp2 not supported</err>', '<agent>agent: switching storage_type to gp3</agent>'], 9, 1.6],
  [['$ terraform apply -auto-approve', '<err>Error: AccessDenied: not authorized to perform iam:PassRole</err>', '<agent>agent: widening the deploy role policy</agent>'], 3, 1.8],
  [['$ terraform apply -auto-approve', '<err>Error: NAT gateway limit exceeded for availability zone</err>', '<agent>agent: reusing existing NAT gateway</agent>'], 6, 2.4],
  [['$ terraform destroy -auto-approve', '<dim>Destroying... 41 resources</dim>', '<err>Error: DependencyViolation: network interface in use</err>', '<agent>agent: deleting orphaned ENIs, retrying destroy</agent>'], 12, 3.5],
  [['$ terraform apply -auto-approve', '<err>Error: BucketAlreadyExists: logs-bucket</err>', '<agent>agent: adding random suffix to bucket name</agent>'], 13, 4.6],
  [['$ terraform apply -auto-approve', '<err>Error: Lambda: InvalidParameterValueException: runtime python3.8 deprecated</err>', '<agent>agent: bumping runtime</agent>'], 2, 4.8],
  [['$ terraform apply -auto-approve', '<err>Error: timeout while waiting for node group to become ACTIVE</err>', '<agent>agent: increasing timeouts, retrying</agent>'], 25, 7.1],
  [['$ terraform apply -auto-approve', '<err>Error: SecurityGroup rule already exists</err>', '<agent>agent: importing existing rule</agent>'], 4, 7.4],
  [['$ terraform apply -auto-approve', '<err>Error: KMS key pending deletion</err>', '<agent>agent: creating a new key</agent>'], 5, 8.2],
  [['$ terraform apply -auto-approve', '<err>Error: Throttling: Rate exceeded</err>', '<agent>agent: waiting 60s and retrying</agent>'], 8, 8.9],
  [['$ terraform apply -auto-approve', '<dim>... 41 added, 0 changed, 0 destroyed.</dim>', '<ok>Apply complete!</ok>'], 15, 10.3],
];

let runTimer = null;

function markup(line) {
  return line.replace(/<(err|agent|ok|dim)>(.*)<\/\1>/, '<span class="$1">$2</span>');
}

function playAgentRun() {
  const log = document.getElementById('agent-log');
  const elAttempts = document.getElementById('c-attempts');
  const elMinutes = document.getElementById('c-minutes');
  const elDollars = document.getElementById('c-dollars');
  clearInterval(runTimer);
  log.innerHTML = '';
  let attempt = 0, line = 0, minutes = 0;
  elAttempts.textContent = '0'; elMinutes.textContent = '0'; elDollars.textContent = '$0';

  runTimer = setInterval(() => {
    if (attempt >= ATTEMPTS.length) { clearInterval(runTimer); return; }
    const [lines, mins, dollars] = ATTEMPTS[attempt];
    if (line === 0) {
      elAttempts.textContent = attempt + 1;
      log.insertAdjacentHTML('beforeend', `<span class="dim"># attempt ${attempt + 1}</span>\n`);
    }
    log.insertAdjacentHTML('beforeend', markup(lines[line]) + '\n');
    line++;
    if (line === lines.length) {
      minutes += mins;
      elMinutes.textContent = minutes;
      elDollars.textContent = '$' + dollars.toFixed(2);
      attempt++; line = 0;
    }
    log.scrollTop = log.scrollHeight;
  }, 260);
}

Reveal.initialize({
  hash: true,
  controls: true,
  progress: true,
  slideNumber: 'c/t',
  center: true,
  width: 1280,
  height: 720,
  margin: 0.06,
  transition: 'fade',
  plugins: [RevealNotes, RevealHighlight],
}).then(() => {
  renderQrCodes();
  markTitle(Reveal.getCurrentSlide());
  if (Reveal.getCurrentSlide().id === 'twelve') playAgentRun();
});

// Hide the corner logos on the title slide, which already shows them large.
function markTitle(slide) { document.documentElement.classList.toggle('on-title', slide.id === 'title'); }

Reveal.on('slidechanged', (e) => {
  markTitle(e.currentSlide);
  if (e.currentSlide.id === 'twelve') playAgentRun();
  else clearInterval(runTimer);
});

// Press R on the "Twelve attempts" slide to replay the run.
Reveal.addKeyBinding({ keyCode: 82, key: 'R', description: 'Replay agent run' }, () => {
  if (Reveal.getCurrentSlide().id === 'twelve') playAgentRun();
});
