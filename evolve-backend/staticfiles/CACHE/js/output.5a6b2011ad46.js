document.addEventListener('DOMContentLoaded', () => {
    function debounce(func, delay) { let timeout; return function (...args) { const context = this; clearTimeout(timeout); timeout = setTimeout(() => func.apply(context, args), delay); }; }
    const phoneInput = document.querySelector('.form-input[type="tel"]'); const waitlistButton = document.querySelector('.waitlist-button'); if (phoneInput && waitlistButton) {
        waitlistButton.disabled = true; phoneInput.addEventListener('input', (e) => {
            let inputValue = e.target.value.replace(/\D/g, ''); if (inputValue.length > 10) { inputValue = inputValue.substring(0, 10); }
            let formattedValue = ''; if (inputValue.length > 0) { formattedValue = '(' + inputValue.substring(0, 3); }
            if (inputValue.length >= 4) { formattedValue += ') ' + inputValue.substring(3, 6); }
            if (inputValue.length >= 7) { formattedValue += '-' + inputValue.substring(6, 10); }
            if (e.inputType === 'deleteContentBackward' && (e.target.value.endsWith(') ') || e.target.value.endsWith('-'))) {
                if (inputValue.length > 0) {
                    inputValue = inputValue.slice(0, -1); formattedValue = ''; if (inputValue.length > 0) { formattedValue = '(' + inputValue.substring(0, 3); }
                    if (inputValue.length >= 4) { formattedValue += ') ' + inputValue.substring(3, 6); }
                    if (inputValue.length >= 7) { formattedValue += '-' + inputValue.substring(6, 10); }
                }
            }
            e.target.value = formattedValue; if (inputValue.length === 10) { waitlistButton.disabled = false; } else { waitlistButton.disabled = true; }
        });
    }
    const schoolInput = document.getElementById('schoolNameInput'); const schoolSuggestions = document.getElementById('schoolSuggestions'); const schoolForm = document.getElementById('schoolForm'); const confirmSchoolButton = document.getElementById('confirmSchoolButton'); if (schoolInput && schoolSuggestions && confirmSchoolButton) {
        let validSchoolSelected = false; const autocompleteUrl = schoolInput.dataset.autocompleteUrl; const initialSchoolName = schoolInput.dataset.initialSchoolName; if (initialSchoolName) { validSchoolSelected = true; confirmSchoolButton.disabled = false; } else { confirmSchoolButton.disabled = true; }
        const debouncedFetchSchools = debounce(async function (term) {
            if (term.length < 2) { schoolSuggestions.style.display = 'none'; return; }
            try {
                const response = await fetch(`${autocompleteUrl}?term=${encodeURIComponent(term)}`); if (!response.ok) { console.error('Error fetching schools:', response.statusText); schoolSuggestions.style.display = 'none'; return; }
                const suggestions = await response.json(); schoolSuggestions.innerHTML = ''; if (suggestions.length > 0) { suggestions.forEach(suggestionText => { const div = document.createElement('div'); div.textContent = suggestionText; div.addEventListener('click', function () { schoolInput.value = this.textContent; schoolSuggestions.innerHTML = ''; schoolSuggestions.style.display = 'none'; validSchoolSelected = true; confirmSchoolButton.disabled = false; schoolInput.focus(); }); schoolSuggestions.appendChild(div); }); schoolSuggestions.style.display = 'block'; } else { schoolSuggestions.style.display = 'none'; }
            } catch (error) { console.error('Request failed:', error); schoolSuggestions.style.display = 'none'; }
        }, 300); schoolInput.addEventListener('input', function () {
            const term = this.value; if (term.trim() === "" && initialSchoolName) { validSchoolSelected = true; confirmSchoolButton.disabled = false; } else if (term.trim() === "") { validSchoolSelected = false; confirmSchoolButton.disabled = true; } else { validSchoolSelected = false; confirmSchoolButton.disabled = true; }
            debouncedFetchSchools(term);
        }); schoolInput.addEventListener('blur', function () { setTimeout(() => { if (!schoolSuggestions.matches(':hover')) { schoolSuggestions.style.display = 'none'; } }, 200); }); document.addEventListener('click', function (e) { if (e.target !== schoolInput && !schoolSuggestions.contains(e.target)) { schoolSuggestions.style.display = 'none'; } }); if (schoolForm) { schoolForm.addEventListener('submit', function (e) { if (!validSchoolSelected && schoolInput.value.trim() !== "") { alert("Please select a valid school from the dropdown list."); e.preventDefault(); } else if (schoolInput.value.trim() === "" && !initialSchoolName) { alert("School name cannot be empty."); e.preventDefault(); } }); }
    }
    const copyIcons = document.querySelectorAll('.copy-icon'); copyIcons.forEach(icon => { icon.addEventListener('click', () => { const textToCopy = icon.dataset.clipboardText; navigator.clipboard.writeText(textToCopy).then(() => { console.log('Referral link copied to clipboard!'); const originalText = icon.textContent; icon.textContent = 'Copied!'; setTimeout(() => { icon.textContent = originalText; }, 2000); }).catch(err => { console.error('Failed to copy text: ', err); }); }); }); const dialogElement = document.getElementById('successDialog'); if (dialogElement) {
        const message = dialogElement.dataset.message; const messageTags = dialogElement.dataset.messageTags; if (message) {
            dialogElement.textContent = message; dialogElement.classList.add('show'); if (message.includes("bumped you up") && typeof confetti === 'function') { confetti({ particleCount: 100, spread: 70, origin: { y: 0.6 } }); }
            setTimeout(() => { dialogElement.classList.remove('show'); dialogElement.classList.add('fade-out'); setTimeout(() => { dialogElement.classList.remove('fade-out'); dialogElement.textContent = ''; }, 500); }, 4000);
        }
    }
});;