import datetime
import re
from docx import Document
from django.core.exceptions import ValidationError, ImproperlyConfigured, AppRegistryNotReady
from ..models import ReadingContent, ContentCard # Adjusted import to relative from parent
from django.utils.dateparse import parse_duration
from django.db import transaction
import os 
import sys

def process_reading_content(docx_file_path):
    """
    Parses a .docx file to extract and create ReadingContent and ContentCard objects
    in the Django database.

    Args:
        docx_file_path (str): The path to the .docx file.

    Returns:
        list: A list of created ReadingContent objects.
              Returns an empty list if the file cannot be processed or DB errors occur.
    """
    try:
        document = Document(docx_file_path)
    except Exception as e:
        print(f"Error opening or reading docx file: {e}")
        return []

    # Check if models are available - basic check, relies on caller context
    try:
        _ = ReadingContent.CATEGORY_CHOICES
    except (NameError, ImproperlyConfigured, AppRegistryNotReady):
         print("Error: Django models not available or app not ready. Run within a Django environment.")
         return []

    created_instances = [] # Renamed from output_data
    current_content_instance = None
    content_cards_data = []
    card_order = 0

    STATE_LOOKING_FOR_TITLE = 0
    STATE_READING_METADATA = 1
    STATE_READING_CARDS = 2

    state = STATE_LOOKING_FOR_TITLE
    metadata_fields = {
        'TITLE': None,
        'DURATION': None,
        'DESCRIPTION': None,
        'CATEGORY': None,
    }

    def _save_previous_content():
        nonlocal current_content_instance, content_cards_data, created_instances, card_order, metadata_fields
        # Check if we have a title
        if metadata_fields['TITLE']:
            title = metadata_fields['TITLE'].strip()
            description = metadata_fields.get('DESCRIPTION', '').strip()

            # --- Category Processing ---
            valid_categories = [choice[0] for choice in ReadingContent.CATEGORY_CHOICES]
            raw_categories = metadata_fields.get('CATEGORY', '')
            categories = []
            if raw_categories:
                parsed_cats = [c.strip() for c in raw_categories.split(',') if c.strip()]
                invalid_categories = [c for c in parsed_cats if c not in valid_categories]
                if invalid_categories:
                    print(f"Warning: Invalid categories found for '{title}': {', '.join(invalid_categories)}. Skipping these categories.")
                    categories = [c for c in parsed_cats if c in valid_categories]
                else:
                    categories = parsed_cats
            else:
                print(f"Warning: Missing CATEGORY for '{title}'. Setting to empty list.")

            # --- Duration Processing ---
            duration_str = metadata_fields.get('DURATION')
            duration_obj = None
            if duration_str:
                duration_obj = parse_duration(duration_str.strip())
                if duration_obj is None:
                    print(f"Warning: Invalid duration format '{duration_str}' for '{title}'. Setting duration to zero.")
                    duration_obj = datetime.timedelta(0)
            else:
                print(f"Warning: Missing DURATION for '{title}'. Setting duration to zero.")
                duration_obj = datetime.timedelta(0)

            # --- Create DB objects ---
            try:
                if not title:
                     print("Error: Cannot save ReadingContent without a TITLE.")
                     # Skip saving this block
                else:
                    with transaction.atomic():
                        current_content_instance = ReadingContent.objects.create(
                            title=title,
                            description=description,
                            category=categories,
                            duration=duration_obj,
                            # cover_image remains blank
                        )

                        for card_data in content_cards_data:
                            try:
                                ContentCard.objects.create(
                                    reading_content=current_content_instance,
                                    text=card_data['text'],
                                    bolded_words=card_data['bolded'],
                                    order=card_data['order']
                                )
                            except ValidationError as ve:
                                print(f"Validation Error creating card for '{current_content_instance.title}': {ve}. Skipping card.")
                            except Exception as card_exc:
                                print(f"Error creating card for '{current_content_instance.title}': {card_exc}. Skipping card.")

                        created_instances.append(current_content_instance)
                        print(f"Successfully created ReadingContent: {current_content_instance.title}")

            except Exception as e:
                print(f"Error saving ReadingContent '{title}': {e}")

        # Reset for next potential content block
        current_content_instance = None
        content_cards_data = []
        card_order = 0
        metadata_fields.update({k: None for k in metadata_fields})


    for para in document.paragraphs:
        text = para.text.strip()

        if not text:
             continue

        title_match = re.search(r"TITLE:\s*(.*)", text, re.IGNORECASE)
        duration_match = re.search(r"DURATION:\s*(.*)", text, re.IGNORECASE)
        description_match = re.search(r"DESCRIPTION:\s*(.*)", text, re.IGNORECASE)
        category_match = re.search(r"CATEGORY:\s*(.*)", text, re.IGNORECASE)

        if title_match:
            _save_previous_content()
            metadata_fields['TITLE'] = title_match.group(1).strip()
            state = STATE_READING_METADATA
            continue

        if state == STATE_READING_METADATA:
            if duration_match:
                metadata_fields['DURATION'] = duration_match.group(1).strip()
            elif description_match:
                metadata_fields['DESCRIPTION'] = description_match.group(1).strip()
            elif category_match:
                metadata_fields['CATEGORY'] = category_match.group(1).strip()
                state = STATE_READING_CARDS
            elif not (duration_match or description_match or category_match):
                 pass
            continue

        if state == STATE_READING_CARDS:
            card_text_content = ""
            bolded_words_in_card = []
            for run in para.runs:
                run_text = run.text
                card_text_content += run_text
                if run.bold:
                    bolded_words_in_card.extend([word for word in run_text.split() if word])

            final_card_text = para.text.strip()
            unique_bolded_words = list(dict.fromkeys(bolded_words_in_card))
            validated_bolded_words = [word for word in unique_bolded_words if word in final_card_text]

            if len(validated_bolded_words) != len(unique_bolded_words):
                missed_words = set(unique_bolded_words) - set(validated_bolded_words)
                print(f"Warning: Some bold words for card '{final_card_text[:30]}...' were not found: {missed_words}")

            if final_card_text:
                content_cards_data.append({
                    'text': final_card_text,
                    'bolded': validated_bolded_words,
                    'order': card_order
                })
                card_order += 1

    # Save the last block
    _save_previous_content()

    return created_instances # Return list of created model instances 