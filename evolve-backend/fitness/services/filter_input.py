import json

raw_input = [{
        "id": "9e22da4f-eb28-4357-aef0-262239fd9b7f",
        "name": "Advanced Kettlebell Windmill",
        "force": "push",
        "level": "intermediate",
        "mechanic": "isolation",
        "equipment": "kettlebells",
        "primary_muscles": [
            "abdominals"
        ],
        "secondary_muscles": [
            "glutes",
            "hamstrings",
            "shoulders"
        ],
        "instructions": [
            "Clean and press a kettlebell overhead with one arm.",
            "Keeping the kettlebell locked out at all times, push your butt out in the direction of the locked out kettlebell. Keep the non-working arm behind your back and turn your feet out at a forty-five degree angle from the arm with the kettlebell.",
            "Lower yourself as far as possible.",
            "Pause for a second and reverse the motion back to the starting position."
        ],
        "category": "strength",
        "picture1": "https://evolve-backend-production4701250738638064907896437.up.railway.app/media/exercises/Advanced_Kettlebell_Windmill_0_Sm3ICQu.jpg",
        "picture2": "https://evolve-backend-production4701250738638064907896437.up.railway.app/media/exercises/Advanced_Kettlebell_Windmill_1_alpikKH.jpg",
        "point_value": 0
    },
    {
        "id": "aa3c4c9b-2b8e-47fc-9d6d-91182a09c5fa",
        "name": "Air Bike",
        "force": "pull",
        "level": "beginner",
        "mechanic": "compound",
        "equipment": "body only",
        "primary_muscles": [
            "abdominals"
        ],
        "secondary_muscles": [],
        "instructions": [
            "Lie flat on the floor with your lower back pressed to the ground. For this exercise, you will need to put your hands beside your head. Be careful however to not strain with the neck as you perform it. Now lift your shoulders into the crunch position.",
            "Bring knees up to where they are perpendicular to the floor, with your lower legs parallel to the floor. This will be your starting position.",
            "Now simultaneously, slowly go through a cycle pedal motion kicking forward with the right leg and bringing in the knee of the left leg. Bring your right elbow close to your left knee by crunching to the side, as you breathe out.",
            "Go back to the initial position as you breathe in.",
            "Crunch to the opposite side as you cycle your legs and bring closer your left elbow to your right knee and exhale.",
            "Continue alternating in this manner until all of the recommended repetitions for each side have been completed."
        ],
        "category": "strength",
        "picture1": "https://evolve-backend-production4701250738638064907896437.up.railway.app/media/exercises/Air_Bike_0_chJPCWD.jpg",
        "picture2": "https://evolve-backend-production4701250738638064907896437.up.railway.app/media/exercises/Air_Bike_1_q0MoTRV.jpg",
        "point_value": 0
    },
    {
        "id": "730de842-e5f5-4231-af0f-70b0a0db09da",
        "name": "All Fours Quad Stretch",
        "force": "static",
        "level": "intermediate",
        "mechanic": "null",
        "equipment": "body only",
        "primary_muscles": [
            "quadriceps"
        ],
        "secondary_muscles": [
            "quadriceps"
        ],
        "instructions": [
            "Start off on your hands and knees, then lift your leg off the floor and hold the foot with your hand.",
            "Use your hand to hold the foot or ankle, keeping the knee fully flexed, stretching the quadriceps and hip flexors.",
            "Focus on extending your hips, thrusting them towards the floor. Hold for 10-20 seconds and then switch sides."
        ],
        "category": "stretching",
        "picture1": "https://evolve-backend-production4701250738638064907896437.up.railway.app/media/exercises/All_Fours_Quad_Stretch_0_p3XpRcS.jpg",
        "picture2": "https://evolve-backend-production4701250738638064907896437.up.railway.app/media/exercises/All_Fours_Quad_Stretch_1_Dl93fae.jpg",
        "point_value": 0
    }]

def clean_json(json_data):
    keys_to_remove = [
        "id",
        "force",
        "level",
        "mechanic",
        "instructions",
        "picture1",
        "picture2",
        "point_value",
        "equipment"
    ]
    
    for key in keys_to_remove:
        json_data.pop(key, None)
    
    return json.dumps(json_data, separators=(',', ':'))

def assemble_input(raw_input):
    cleaned_data = []
    for item in raw_input:
        cleaned_item = json.loads(clean_json(item))
        cleaned_data.append(cleaned_item)
    return cleaned_data

if __name__ == '__main__':
    # Assemble the cleaned data
    data = assemble_input(raw_input)
    
    # Write the output to a JSON file
    with open("output.json", "w") as f:
        json.dump(data, f, separators=(',', ':'))
        
    print("Output successfully written to output.json")




