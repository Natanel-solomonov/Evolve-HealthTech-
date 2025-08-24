// evolve-backend/api/static/api/admin/js/char_count.js
document.addEventListener('DOMContentLoaded', function() {
    // Use a selector that targets the textarea within the specific formset or field wrapper if necessary
    // This basic selector assumes 'id_text' is unique enough on the admin page.
    const textField = document.getElementById('id_text');

    if (textField && textField.form.action.includes('/api/maxproposition/')) { // Check if it's the correct form
        // Create the counter element
        const counter = document.createElement('div');
        counter.style.marginTop = '5px';
        counter.style.fontSize = '0.9em';
        counter.style.color = '#fff';
        counter.style.paddingLeft = '10px';
        counter.id = 'char-counter';

        // Insert the counter right after the textarea
        textField.parentNode.insertBefore(counter, textField.nextSibling);

        // Function to update the counter
        const updateCounter = () => {
            const currentLength = textField.value.length;
            counter.textContent = `${currentLength} characters`;
        };

        // Initial update
        updateCounter();

        // Update counter on input, keyup (for immediate feedback on backspace/delete), and focus/blur
        textField.addEventListener('input', updateCounter);
        textField.addEventListener('keyup', updateCounter);
        textField.addEventListener('focus', updateCounter);
        textField.addEventListener('blur', updateCounter);

    } else if (document.getElementById('id_text')){
        // Don't log an error if id_text exists but isn't for MaxProposition, might be another field
        // console.log("Textarea with id 'id_text' found, but not within the MaxProposition admin form.");
    } else {
        console.warn("Textarea with id 'id_text' not found for char count.");
    }
}); 