document.addEventListener('DOMContentLoaded', () => {
    // Debounce function
    function debounce(func, delay) {
        let timeout;
        return function(...args) {
            const context = this;
            clearTimeout(timeout);
            timeout = setTimeout(() => func.apply(context, args), delay);
        };
    }

    const phoneInput = document.querySelector('.form-input[type="tel"]');
    const waitlistButton = document.querySelector('.waitlist-button'); // Get the button

    if (phoneInput && waitlistButton) { // Check if both elements exist
        waitlistButton.disabled = true; // Disable button initially

        phoneInput.addEventListener('input', (e) => {
            let inputValue = e.target.value.replace(/\D/g, ''); // Remove all non-digits

            // Limit to 10 digits
            if (inputValue.length > 10) {
                inputValue = inputValue.substring(0, 10);
            }

            let formattedValue = '';
            if (inputValue.length > 0) {
                formattedValue = '(' + inputValue.substring(0, 3);
            }
            if (inputValue.length >= 4) {
                formattedValue += ') ' + inputValue.substring(3, 6);
            }
            if (inputValue.length >= 7) {
                formattedValue += '-' + inputValue.substring(6, 10);
            }
            
            // If the user is deleting and the cursor is at a formatting character, 
            // we need to adjust. This is a simplified handling.
            // A more robust solution would involve cursor position tracking.
            if (e.inputType === 'deleteContentBackward' && (e.target.value.endsWith(') ') || e.target.value.endsWith('-'))) {
                 // Allow natural deletion of formatting characters by re-evaluating one char less
                if (inputValue.length > 0) { // ensure we don't go negative
                    inputValue = inputValue.slice(0, -1);
                     // Re-apply formatting with one less digit
                    formattedValue = '';
                    if (inputValue.length > 0) {
                        formattedValue = '(' + inputValue.substring(0, 3);
                    }
                    if (inputValue.length >= 4) {
                        formattedValue += ') ' + inputValue.substring(3, 6);
                    }
                    if (inputValue.length >= 7) {
                        formattedValue += '-' + inputValue.substring(6, 10);
                    }
                }
            }

            e.target.value = formattedValue;

            // Enable/disable button based on digit count
            if (inputValue.length === 10) {
                waitlistButton.disabled = false;
            } else {
                waitlistButton.disabled = true;
            }
        });
    }

    // School Autocomplete Logic (moved from position.html)
    const schoolInput = document.getElementById('schoolNameInput');
    const schoolSuggestions = document.getElementById('schoolSuggestions');
    const schoolForm = document.getElementById('schoolForm');
    const confirmSchoolButton = document.getElementById('confirmSchoolButton');
    
    if (schoolInput && schoolSuggestions && confirmSchoolButton) {
        let validSchoolSelected = false;
        const autocompleteUrl = schoolInput.dataset.autocompleteUrl;
        const initialSchoolName = schoolInput.dataset.initialSchoolName;

        // Set initial value from data attribute (though it's also set by Django template in value attribute)
        // schoolInput.value = initialSchoolName;

        if (initialSchoolName) {
            validSchoolSelected = true; // Assume initial value is valid
            confirmSchoolButton.disabled = false;
        } else {
            confirmSchoolButton.disabled = true;
        }

        // Debounced version of the fetch logic
        const debouncedFetchSchools = debounce(async function(term) {
            if (term.length < 2) {
                schoolSuggestions.style.display = 'none';
                return;
            }

            try {
                const response = await fetch(`${autocompleteUrl}?term=${encodeURIComponent(term)}`);
                if (!response.ok) {
                    console.error('Error fetching schools:', response.statusText);
                    schoolSuggestions.style.display = 'none';
                    return;
                }
                const suggestions = await response.json();
                
                schoolSuggestions.innerHTML = ''; // Clear previous suggestions before adding new ones
                if (suggestions.length > 0) {
                    suggestions.forEach(suggestionText => {
                        const div = document.createElement('div');
                        div.textContent = suggestionText;
                        div.addEventListener('click', function() {
                            schoolInput.value = this.textContent;
                            schoolSuggestions.innerHTML = '';
                            schoolSuggestions.style.display = 'none';
                            validSchoolSelected = true;
                            confirmSchoolButton.disabled = false;
                            schoolInput.focus();
                        });
                        schoolSuggestions.appendChild(div);
                    });
                    schoolSuggestions.style.display = 'block';
                } else {
                    schoolSuggestions.style.display = 'none';
                }
            } catch (error) {
                console.error('Request failed:', error);
                schoolSuggestions.style.display = 'none';
            }
        }, 300); // 300ms delay

        schoolInput.addEventListener('input', function() {
            const term = this.value;
            // Manage button state based on input, but call debounced fetch
            if (term.trim() === "" && initialSchoolName) {
                validSchoolSelected = true; 
                confirmSchoolButton.disabled = false; 
            } else if (term.trim() === "") {
                validSchoolSelected = false;
                confirmSchoolButton.disabled = true;
            } else {
                validSchoolSelected = false;
                confirmSchoolButton.disabled = true;
            }
            debouncedFetchSchools(term);
        });

        schoolInput.addEventListener('blur', function() {
            setTimeout(() => {
                if (!schoolSuggestions.matches(':hover')) {
                   schoolSuggestions.style.display = 'none';
                }
            }, 200);
        });
        
        document.addEventListener('click', function(e) {
            if (e.target !== schoolInput && !schoolSuggestions.contains(e.target)) {
                schoolSuggestions.style.display = 'none';
            }
        });

        if (schoolForm) {
            schoolForm.addEventListener('submit', function(e) {
                if (!validSchoolSelected && schoolInput.value.trim() !== "") {
                    alert("Please select a valid school from the dropdown list.");
                    e.preventDefault();
                } else if (schoolInput.value.trim() === "" && !initialSchoolName) {
                     alert("School name cannot be empty.");
                     e.preventDefault();
                }
            });
        }
    }

    // Copy to clipboard for referral link (assuming this was also in position.html or intended to be general)
    const copyIcons = document.querySelectorAll('.copy-icon');
    copyIcons.forEach(icon => {
        icon.addEventListener('click', () => {
            const textToCopy = icon.dataset.clipboardText;
            navigator.clipboard.writeText(textToCopy).then(() => {
                console.log('Referral link copied to clipboard!');
                const originalText = icon.textContent;
                icon.textContent = 'Copied!';
                setTimeout(() => { icon.textContent = originalText; }, 2000);
            }).catch(err => {
                console.error('Failed to copy text: ', err);
            });
        });
    });

    // Success Dialog Logic
    const dialogElement = document.getElementById('successDialog');
    if (dialogElement) {
        const message = dialogElement.dataset.message;
        const messageTags = dialogElement.dataset.messageTags;

        if (message) {
            dialogElement.textContent = message;
            dialogElement.classList.add('show');

            // Check if the message indicates a position bump and trigger confetti
            if (message.includes("bumped you up") && typeof confetti === 'function') {
                confetti({
                    particleCount: 100,
                    spread: 70,
                    origin: { y: 0.6 }
                });
            }

            // Hide after a few seconds (e.g., 4 seconds)
            setTimeout(() => {
                dialogElement.classList.remove('show');
                dialogElement.classList.add('fade-out');
                // Optional: remove the element or clear text after fade out completes
                setTimeout(() => {
                    dialogElement.classList.remove('fade-out');
                    dialogElement.textContent = ''; // Clear content
                     // dialogElement.style.visibility = 'hidden'; // Ensure it is fully hidden
                }, 500); // Matches transition duration
            }, 4000);
        }
    }
}); 