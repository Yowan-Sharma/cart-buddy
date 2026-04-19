// Mock Data for Live Orders
const mockOrders = [
    {
        host: "Alex",
        location: "University Library",
        restaurant: "Burger King",
        spotsFilled: 2,
        spotsTotal: 4,
        timeRemaining: "12 mins",
        bgColor: "#FFC800"
    },
    {
        host: "Sarah",
        location: "North Hostel",
        restaurant: "Dominos Pizza",
        spotsFilled: 3,
        spotsTotal: 5,
        timeRemaining: "5 mins",
        bgColor: "#1CB0F6"
    },
    {
        host: "Mike",
        location: "Tech Park",
        restaurant: "Sweet Truth",
        spotsFilled: 1,
        spotsTotal: 3,
        timeRemaining: "15 mins",
        bgColor: "#58CC02"
    }
];

// Populate Live Orders
function renderLiveOrders() {
    const grid = document.getElementById('orders-grid');
    grid.innerHTML = '';

    mockOrders.forEach(order => {
        const percentage = (order.spotsFilled / order.spotsTotal) * 100;
        
        const card = document.createElement('div');
        card.className = 'order-card';
        card.innerHTML = `
            <div class="order-card-header">
                <div class="avatar" style="background-color: ${order.bgColor}">${order.host[0]}</div>
                <div class="order-info">
                    <h3>${order.restaurant}</h3>
                    <p>📍 ${order.location} &bull; Hosted by ${order.host}</p>
                </div>
            </div>
            <div class="order-progress">
                <div class="progress-bar" style="width: ${percentage}%"></div>
            </div>
            <div class="order-meta">
                <span>👥 ${order.spotsFilled}/${order.spotsTotal} Buddies</span>
                <span class="highlight">⏳ ${order.timeRemaining}</span>
            </div>
            <button class="btn btn-primary" onclick="wiggleBtn(this)">Join Cart</button>
        `;
        grid.appendChild(card);
    });
}

// Micro-interaction
function wiggleBtn(btn) {
    btn.style.transition = "transform 0.1s";
    btn.style.transform = "translateX(-5px)";
    setTimeout(() => btn.style.transform = "translateX(5px)", 100);
    setTimeout(() => btn.style.transform = "translateX(-5px)", 200);
    setTimeout(() => btn.style.transform = "translateX(5px)", 300);
    setTimeout(() => btn.style.transform = "none", 400);
}

// Number Counter Animation
function animateCounters() {
    const counters = document.querySelectorAll('.counter');
    const speed = 100; // The lower the slower

    counters.forEach(counter => {
        const updateCount = () => {
            const target = +counter.getAttribute('data-target');
            const count = +counter.innerText.replace(/[^0-9]/g, '');

            const inc = target / speed;

            if (count < target) {
                // Formatting for currency if it started with ₹
                const hasRupee = counter.innerText.includes('₹');
                const newCount = Math.ceil(count + inc);
                counter.innerText = hasRupee ? '₹' + newCount.toLocaleString() : newCount.toLocaleString();
                setTimeout(updateCount, 20);
            } else {
                const hasRupee = counter.innerText.includes('₹');
                counter.innerText = (hasRupee ? '₹' : '') + target.toLocaleString() + '+';
            }
        };

        // Observer triggered
        updateCount();
    });
}

// Intersection Observer for Scroll Animations
const observerOptions = {
    threshold: 0.5
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            if (entry.target.id === 'stats') {
                animateCounters();
                observer.unobserve(entry.target);
            }
        }
    });
}, observerOptions);

// Dark Mode Toggle Logic
function initThemeToggle() {
    const toggleBtn = document.getElementById('theme-toggle');
    if (!toggleBtn) return;
    
    // Check local storage for preference
    const savedTheme = localStorage.getItem('cartbuddy-theme');
    if (savedTheme === 'dark' || (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
        document.body.classList.add('dark-mode');
        toggleBtn.innerText = '☀️';
    }

    toggleBtn.addEventListener('click', () => {
        document.body.classList.toggle('dark-mode');
        if (document.body.classList.contains('dark-mode')) {
            localStorage.setItem('cartbuddy-theme', 'dark');
            toggleBtn.innerText = '☀️';
        } else {
            localStorage.setItem('cartbuddy-theme', 'light');
            toggleBtn.innerText = '🌙';
        }
    });
}

// Scroll Progress Bar Logic
function initScrollProgress() {
    const progressBar = document.getElementById('scroll-progress');
    if (!progressBar) return;

    window.addEventListener('scroll', () => {
        // Calculate scroll percentage
        const scrollTop = window.scrollY || document.documentElement.scrollTop;
        const scrollHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
        const scrollPercentage = Math.min((scrollTop / scrollHeight) * 100, 100);
        
        // Apply width and smooth animation
        progressBar.style.width = scrollPercentage + '%';
    });
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    renderLiveOrders();
    initThemeToggle();
    initScrollProgress();
    
    // Start observing stats section
    const statsSection = document.getElementById('stats');
    if (statsSection) {
        observer.observe(statsSection);
    }
});
