import fs from 'fs';
import path from 'path';
import assert from 'assert';

console.log('--- Running Authority Web UI Invariants Test Suite ---');

const appJsxPath = path.resolve('src/App.jsx');
const listJsxPath = path.resolve('src/components/MissingPersonsList.jsx');
const navbarJsxPath = path.resolve('src/components/Navbar.jsx');
const modalJsxPath = path.resolve('src/components/SightingDetailModal.jsx');
const queueJsxPath = path.resolve('src/components/SightingsQueue.jsx');

// 1. Check App.jsx does NOT contain a "Register Missing Person" button
const appJsx = fs.readFileSync(appJsxPath, 'utf8');
const appButtonMatches = (appJsx.match(/<button[^>]*>[^<]*Register Missing Person[^<]*<\/button>/g) || []).length;
assert.strictEqual(
  appButtonMatches, 
  0, 
  `Expected 0 'Register Missing Person' buttons in App.jsx (should only be in MissingPersonsList), found ${appButtonMatches}`
);
console.log('✓ App.jsx has no duplicate Register Missing Person button');

// 2. Check MissingPersonsList.jsx has exactly ONE "Register Missing Person" button
const listJsx = fs.readFileSync(listJsxPath, 'utf8');
const listRegisterMatches = (listJsx.match(/Register Missing Person/g) || []).length;
assert.strictEqual(
  listRegisterMatches, 
  1, 
  `Expected exactly 1 'Register Missing Person' button in MissingPersonsList.jsx, found ${listRegisterMatches}`
);
console.log('✓ MissingPersonsList.jsx has exactly 1 Register Missing Person button');

// 3. Check Navbar.jsx enforces POLICE department for missing persons navigation
const navbarJsx = fs.readFileSync(navbarJsxPath, 'utf8');
assert.ok(
  navbarJsx.includes("toUpperCase() === 'POLICE'") || navbarJsx.includes("department === 'POLICE'"),
  'Navbar.jsx must enforce POLICE department check for missing persons links'
);
console.log('✓ Navbar.jsx restricts missing-person navigation to POLICE department');

// 4. Check SightingDetailModal.jsx has verify & reject review actions and resolved-case handling
const modalJsx = fs.readFileSync(modalJsxPath, 'utf8');
assert.ok(
  modalJsx.includes("handleVerificationAction('verify')"),
  'SightingDetailModal.jsx must have verify action'
);
assert.ok(
  modalJsx.includes("handleVerificationAction('reject')"),
  'SightingDetailModal.jsx must have reject action'
);
assert.ok(
  modalJsx.includes('Historical Sighting') || modalJsx.includes('is_case_resolved'),
  'SightingDetailModal.jsx must have resolved-case banner handling'
);
console.log('✓ SightingDetailModal.jsx provides officer verify/reject workflow and resolved-case banners');

// 5. Check SightingsQueue.jsx has resolved-case status badges
const queueJsx = fs.readFileSync(queueJsxPath, 'utf8');
assert.ok(
  queueJsx.includes('Case Resolved') || queueJsx.includes('is_case_resolved'),
  'SightingsQueue.jsx must display resolved case indicator'
);
console.log('✓ SightingsQueue.jsx displays resolved case status indicators');

// 6. Check that redundant AuthorityLoginModal component is removed
const modalFilePath = path.resolve('src/components/AuthorityLoginModal.jsx');
assert.ok(
  !fs.existsSync(modalFilePath),
  'AuthorityLoginModal.jsx should be completely removed to eliminate redundant login screen'
);
assert.ok(
  !appJsx.includes('AuthorityLoginModal'),
  'App.jsx must not import or render AuthorityLoginModal'
);
console.log('✓ Redundant AuthorityLoginModal is completely eliminated from App.jsx and codebase');

// 7. Check that obsolete branding strings are not present in src/
const srcDir = path.resolve('src');
function checkNoObsoleteBranding(dir) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      checkNoObsoleteBranding(fullPath);
    } else if (file.endsWith('.jsx') || file.endsWith('.js')) {
      const content = fs.readFileSync(fullPath, 'utf8');
      assert.ok(
        !content.includes('Mumbai Police & Civic Issue Law Enforcement Portal'),
        `Obsolete branding found in ${file}`
      );
    }
  }
}
checkNoObsoleteBranding(srcDir);
console.log('✓ Obsolete modal branding ("Mumbai Police & Civic Issue Law Enforcement Portal") is absent from all src files');

// 8. Check that unauthenticated users are redirected to authority portal login
assert.ok(
  appJsx.includes('redirectToAuthorityLogin()'),
  'App.jsx must trigger redirectToAuthorityLogin when unauthenticated'
);
const navbarJsxContent = fs.readFileSync(navbarJsxPath, 'utf8');
assert.ok(
  !navbarJsxContent.includes('onOpenLogin'),
  'Navbar.jsx must not use onOpenLogin'
);
assert.ok(
  navbarJsxContent.includes('redirectToAuthorityLogin'),
  'Navbar.jsx must use redirectToAuthorityLogin for unauthenticated state'
);
console.log('✓ Single authority portal login redirect is properly wired in App.jsx and Navbar.jsx');

console.log('\nAll Authority Web UI invariant tests passed successfully! (8/8)');
