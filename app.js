// AgentStreak — static frontend. No backend, no server, no stored sessions.
// Writes go ONLY through the user's own connected wallet.
// NEVER ask for a seed phrase, QR code, or pairing code.

const CONTRACT_ADDRESS = "0x3ce06B00DE25d6062D771664C231bb7Af725ecdb"; // Deployed 18 Nov 2026, tx 0x28e466571d0e58da5ed42dc348024fceb4af6d55b54cc1001353894bd2fd9482
const AGENT_ID_ADDRESS = "0x60b9262456de011f7d15a54cdd8c48baaa8b022f";
const BSC_CHAIN_ID = 56;
const BSCSCAN = "https://bscscan.com";
const RPC_URLS = [
  "https://bsc-dataseed.bnbchain.org",
  "https://bsc-dataseed2.bnbchain.org",
];
const ZERO = "0x0000000000000000000000000000000000000000";

const AGENTSTREAK_ABI = [
  "function claim()",
  "function getStreak(address) view returns (uint32)",
  "function getStats(address) view returns (uint32 streak, uint32 totalClaims, uint64 lastClaimDay, bool hasBadge)",
  "function totalClaimants() view returns (uint256)",
  "function getClaimants(uint256 offset, uint256 limit) view returns (address[])",
  "event Claimed(address indexed user, uint64 day, uint32 streak, uint32 totalClaims)",
  "event BadgeMinted(address indexed user, uint256 indexed tokenId)",
  "function balanceOf(address) view returns (uint256)",
  "function ownerOf(uint256) view returns (address)",
  "function tokenURI(uint256) view returns (string)",
];
const AGENT_ID_ABI = [
  "function balanceOf(address) view returns (uint256)",
];

// ---- DOM ----
const $ = (id) => document.getElementById(id);
const els = {
  connectBtn: $("connectBtn"), addressDisplay: $("addressDisplay"),
  networkWarning: $("networkWarning"), switchNetworkBtn: $("switchNetworkBtn"),
  noProvider: $("noProvider"), notDeployed: $("notDeployed"), errorBox: $("errorBox"),
  agentIdStatus: $("agentIdStatus"), streakNum: $("streakNum"),
  totalClaimsNum: $("totalClaimsNum"), lastClaimDay: $("lastClaimDay"),
  countdown: $("countdown"), claimBtn: $("claimBtn"), claimStatus: $("claimStatus"),
  txResult: $("txResult"), badgeStatus: $("badgeStatus"), badgeMeta: $("badgeMeta"),
  badgeTokenId: $("badgeTokenId"), lbStatus: $("lbStatus"),
  progressLine: $("progressLine"), lbTable: $("lbTable"), lbBody: $("lbBody"),
};

const DEPLOYED = CONTRACT_ADDRESS.toLowerCase() !== ZERO;
const DAY_SECONDS = 86400;

let readProvider = null;   // public RPC, read-only
let walletProvider = null; // user's injected wallet (ethers BrowserProvider)
let signer = null;
let userAddress = null;
let hasAgentId = false;
let alreadyClaimedToday = false;
let countdownTimer = null;

// ---- helpers ----
function showError(msg) {
  els.errorBox.textContent = msg;
  els.errorBox.classList.remove("hidden");
}
function clearError() { els.errorBox.classList.add("hidden"); els.errorBox.textContent = ""; }
function shortAddr(a) { return a.slice(0, 6) + "…" + a.slice(-4); }
function todayDayNumber() { return Math.floor(Date.now() / 1000 / DAY_SECONDS); }
function nextClaimIn() {
  const now = Date.now();
  const nextMidnight = (Math.floor(now / DAY_SECONDS) + 1) * DAY_SECONDS * 1000;
  const ms = nextMidnight - now;
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  const s = Math.floor((ms % 60000) / 1000);
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}
function startCountdown() {
  if (countdownTimer) return;
  const tick = () => { els.countdown.textContent = nextClaimIn(); };
  tick();
  countdownTimer = setInterval(tick, 1000);
}
function setClaimButton() {
  const b = els.claimBtn;
  if (!userAddress) { b.disabled = true; b.textContent = "Connect wallet first"; return; }
  if (!DEPLOYED) { b.disabled = true; b.textContent = "Contract not deployed yet"; return; }
  if (!hasAgentId) { b.disabled = true; b.textContent = "No Agent ID — cannot claim"; return; }
  if (alreadyClaimedToday) { b.disabled = true; b.textContent = "Already claimed today"; return; }
  b.disabled = false; b.textContent = "Claim today's streak";
}

async function getReadProvider() {
  if (readProvider) return readProvider;
  for (const url of RPC_URLS) {
    try {
      const p = new ethers.JsonRpcProvider(url);
      await p.getBlockNumber(); // verify it answers
      readProvider = p;
      return p;
    } catch (e) { /* try next RPC */ }
  }
  throw new Error("All public BSC RPCs unreachable.");
}

// ---- wallet ----
async function connectWallet() {
  clearError();
  if (!window.ethereum) {
    els.noProvider.classList.remove("hidden");
    return;
  }
  try {
    walletProvider = new ethers.BrowserProvider(window.ethereum);
    const accounts = await walletProvider.send("eth_requestAccounts", []);
    userAddress = accounts[0];
    signer = await walletProvider.getSigner();
    els.addressDisplay.textContent = shortAddr(userAddress);
    els.addressDisplay.classList.remove("hidden");
    els.connectBtn.textContent = "Connected";
    els.connectBtn.disabled = true;
    await checkNetwork();
    await refreshAll();
  } catch (e) {
    showError("Wallet connection failed: " + (e?.message || e));
  }
}

async function checkNetwork() {
  try {
    const net = await walletProvider.getNetwork();
    const wrong = Number(net.chainId) !== BSC_CHAIN_ID;
    els.networkWarning.classList.toggle("hidden", !wrong);
    return !wrong;
  } catch (e) {
    els.networkWarning.classList.remove("hidden");
    return false;
  }
}

async function switchToBsc() {
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: "0x38" }],
    });
  } catch (e) {
    // 4902: chain not added — add it, then the user switches.
    if (e?.code === 4902) {
      try {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [{
            chainId: "0x38", chainName: "BNB Smart Chain",
            nativeCurrency: { name: "BNB", symbol: "BNB", decimals: 18 },
            rpcUrls: RPC_URLS, blockExplorerUrls: [BSCSCAN],
          }],
        });
      } catch (e2) { showError("Could not add BNB Smart Chain: " + (e2?.message || e2)); }
    } else {
      showError("Network switch failed: " + (e?.message || e));
    }
  }
}

// ---- reads ----
async function refreshAll() {
  if (!userAddress) return;
  try {
    const rp = await getReadProvider();
    const agentId = new ethers.Contract(AGENT_ID_ADDRESS, AGENT_ID_ABI, rp);
    const bal = await agentId.balanceOf(userAddress);
    hasAgentId = bal > 0n;
    els.agentIdStatus.textContent = hasAgentId
      ? "✓ You hold an Agent ID"
      : "✗ No Agent ID held by this address";
    els.agentIdStatus.style.color = hasAgentId ? "var(--green)" : "var(--red)";
  } catch (e) {
    els.agentIdStatus.textContent = "Could not check Agent ID (RPC error)";
    showError("Agent ID check failed: " + (e?.message || e));
  }

  if (!DEPLOYED) {
    els.streakNum.textContent = "–";
    els.totalClaimsNum.textContent = "–";
    els.lastClaimDay.textContent = "–";
    els.badgeStatus.textContent = "Contract not deployed yet";
    setClaimButton();
    return;
  }

  try {
    const rp = await getReadProvider();
    const c = new ethers.Contract(CONTRACT_ADDRESS, AGENTSTREAK_ABI, rp);
    const [streak, totalClaims, lastClaimDay, hasBadge] =
      await c.getStats(userAddress);
    els.streakNum.textContent = String(streak);
    els.totalClaimsNum.textContent = String(totalClaims);
    els.lastClaimDay.textContent = lastClaimDay === 0n
      ? "never"
      : "day " + String(lastClaimDay);
    alreadyClaimedToday = Number(lastClaimDay) === todayDayNumber();
    startCountdown();
    els.claimStatus.textContent = alreadyClaimedToday
      ? "You already claimed today. Come back tomorrow."
      : hasAgentId ? "Ready to claim." : "You need an Agent ID to claim.";
    await refreshBadge(c, hasBadge);
  } catch (e) {
    showError("Streak read failed: " + (e?.message || e));
  }
  setClaimButton();
}

async function refreshBadge(contract, hasBadge) {
  if (!hasBadge) {
    els.badgeStatus.textContent = "No badge yet — claim once to mint it";
    els.badgeMeta.textContent = "";
    els.badgeTokenId.textContent = "";
    return;
  }
  const tokenId = BigInt(userAddress); // badge tokenId = address as number
  els.badgeTokenId.textContent = "Badge tokenId: " + tokenId.toString();
  try {
    const owner = await contract.ownerOf(tokenId);
    els.badgeStatus.textContent = owner.toLowerCase() === userAddress.toLowerCase()
      ? "✓ Badge minted (soulbound)"
      : "Badge exists but is owned by another address";
    try {
      const uri = await contract.tokenURI(tokenId);
      if (uri.startsWith("data:application/json;base64,")) {
        const meta = JSON.parse(atob(uri.split(",")[1]));
        els.badgeMeta.textContent = meta.name ? `${meta.name} — ${meta.description || ""}` : uri;
      } else {
        els.badgeMeta.textContent = "Metadata: " + uri;
      }
    } catch (e) { els.badgeMeta.textContent = "Metadata unavailable."; }
  } catch (e) {
    els.badgeStatus.textContent = "Badge status unknown (read error)";
  }
}

// ---- claim (write — user confirms in their own wallet) ----
async function onClaim() {
  clearError();
  els.txResult.textContent = "";
  if (!DEPLOYED || !signer || !hasAgentId || alreadyClaimedToday) return;
  const onChain = await checkNetwork();
  if (!onChain) { showError("Switch to BNB Smart Chain first."); return; }
  els.claimBtn.disabled = true;
  els.claimBtn.textContent = "Waiting for wallet confirmation…";
  els.claimStatus.textContent = "Confirm the transaction in your wallet. AgentStreak never asks for your seed phrase or QR code.";
  try {
    const c = new ethers.Contract(CONTRACT_ADDRESS, AGENTSTREAK_ABI, signer);
    const tx = await c.claim(); // user confirms gas + tx in their wallet
    els.txResult.innerHTML = `Transaction sent: <a href="${BSCSCAN}/tx/${tx.hash}" target="_blank" rel="noopener">${tx.hash}</a> — waiting for confirmation…`;
    const receipt = await tx.wait();
    if (receipt.status === 1) {
      els.claimStatus.textContent = "✓ Claimed! Streak updated.";
      els.txResult.innerHTML = `Confirmed: <a href="${BSCSCAN}/tx/${tx.hash}" target="_blank" rel="noopener">${tx.hash}</a>`;
      await refreshAll();
      await loadLeaderboard();
    } else {
      showError("Transaction reverted on-chain. See BscScan: " + BSCSCAN + "/tx/" + tx.hash);
    }
  } catch (e) {
    // User rejection (4001) or revert — surface the reason, don't retry silently.
    showError("Claim failed: " + (e?.reason || e?.message || e));
  } finally {
    setClaimButton();
  }
}

// ---- leaderboard: Claimed events first, fallback to getClaimants paging ----
async function loadLeaderboard() {
  if (!DEPLOYED) { els.lbStatus.textContent = "Waiting for contract deployment…"; return; }
  els.lbStatus.textContent = "Loading leaderboard…";
  try {
    const rp = await getReadProvider();
    const c = new ethers.Contract(CONTRACT_ADDRESS, AGENTSTREAK_ABI, rp);
    const total = Number(await c.totalClaimants());
    els.progressLine.textContent = total >= 30
      ? total + " / 30 Agent IDs claimed — goal reached!"
      : total + " / 30 Agent IDs claimed — " + (30 - total) + " more to go";
    let rows = [];
    try {
      // Latest-first: pull Claimed events, dedupe by user, keep best streak.
      const events = await c.queryFilter(c.filters.Claimed(), 0, "latest");
      const best = new Map();
      for (const ev of events) {
        const u = ev.args.user;
        const s = Number(ev.args.streak), t = Number(ev.args.totalClaims);
        const cur = best.get(u);
        if (!cur || s > cur.streak || (s === cur.streak && t > cur.totalClaims)) {
          best.set(u, { address: u, streak: s, totalClaims: t });
        }
      }
      rows = [...best.values()];
    } catch (e) {
      // Public RPC event range too large / pruned — fall back to paging claimants.
      const PAGE = 500;
      const addrs = [];
      for (let off = 0; off < total; off += PAGE) {
        const page = await c.getClaimants(off, Math.min(PAGE, total - off));
        addrs.push(...page);
      }
      const stats = await Promise.all(addrs.map((a) => c.getStats(a)));
      rows = addrs.map((a, i) => ({
        address: a, streak: Number(stats[i][0]), totalClaims: Number(stats[i][1]),
      }));
    }
    rows.sort((a, b) => b.streak - a.streak || b.totalClaims - a.totalClaims);
    renderLeaderboard(rows.slice(0, 20));
  } catch (e) {
    els.lbStatus.textContent = "Leaderboard unavailable: " + (e?.message || e);
  }
}

function renderLeaderboard(rows) {
  if (!rows.length) { els.lbStatus.textContent = "No claimants yet — be the first!"; return; }
  els.lbStatus.classList.add("hidden");
  els.lbTable.classList.remove("hidden");
  els.lbBody.innerHTML = rows.map((r, i) => `
    <tr>
      <td>${i + 1}</td>
      <td class="addr"><a href="${BSCSCAN}/address/${r.address}" target="_blank" rel="noopener">${shortAddr(r.address)}</a></td>
      <td>${r.streak}</td>
      <td>${r.totalClaims}</td>
    </tr>`).join("");
}

// ---- wire up ----
els.connectBtn.addEventListener("click", connectWallet);
els.switchNetworkBtn.addEventListener("click", switchToBsc);
els.claimBtn.addEventListener("click", onClaim);

if (window.ethereum) {
  window.ethereum.on?.("accountsChanged", (accs) => {
    userAddress = accs[0] || null;
    if (!userAddress) { location.reload(); return; }
    signer = null;
    walletProvider.getSigner().then((s) => { signer = s; refreshAll(); });
  });
  window.ethereum.on?.("chainChanged", () => { checkNetwork(); });
} else {
  els.noProvider.classList.remove("hidden");
}

if (!DEPLOYED) {
  els.notDeployed.classList.remove("hidden");
  setClaimButton();
} else {
  els.notDeployed.classList.add("hidden");
  loadLeaderboard();
}
