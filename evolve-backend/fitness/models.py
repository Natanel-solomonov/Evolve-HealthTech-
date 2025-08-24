from django.db import models
import uuid
import datetime
from django.core.validators import MinValueValidator


class Exercise(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)   
    name = models.CharField(max_length=255)
    force = models.CharField(max_length=100, null=True, blank=True)
    level = models.CharField(max_length=100)    
    mechanic = models.CharField(max_length=100, null=True, blank=True)
    equipment = models.CharField(max_length=100, blank=True, default='None')
    isCardio = models.BooleanField(default=False)
    primary_muscles = models.JSONField()
    secondary_muscles = models.JSONField(null=True, blank=True)
    instructions = models.JSONField()
    category = models.CharField(max_length=100)
    picture1 = models.ImageField(upload_to='exercises/', blank=True, null=True)
    picture2 = models.ImageField(upload_to='exercises/', blank=True, null=True)
    isDiagnostic = models.BooleanField(default=False)

    CLUSTER_CHOICES = [
        ('Vertical Push', 'Vertical Push'),
        ('Horizontal Push', 'Horizontal Push'),
        ('Vertical Pull', 'Vertical Pull'),
        ('Horizontal Pull', 'Horizontal Pull'),
        ('Hip Hinge', 'Hip Hinge'),
        ('Knee Dominant', 'Knee Dominant'),
        ('Core Brace', 'Core Brace'),
    ]

  

    cluster = models.CharField(
        max_length=100,
        choices=CLUSTER_CHOICES,
        null=True,
        blank=True
    )
   
    @classmethod
    def search_exercises(cls, level, equipment, primary_muscles, secondary_muscles, category):
        """
        Search for exercises based on specific criteria:
        - level must match exactly
        - equipment must be one that the user has (in the provided equipment list)
        - primary_muscles and secondary_muscles should match any of the provided muscles
        - category must match exactly
        
        Args:
            level (str): Exercise difficulty level
            equipment (list): List of equipment the user has available
            primary_muscles (list): List of primary muscles to target
            secondary_muscles (list): List of secondary muscles to target
            category (str): Exercise category
            
        Returns:
            QuerySet: Filtered exercise queryset
        """
        from django.db.models import Q
        import json
        
        # Start with base queryset
        queryset = cls.objects.all()
        
        # Filter by exact level match
        if level:
            queryset = queryset.filter(level=level)
        
        # Filter by equipment (only include exercises with equipment user has)
        if equipment:
            # Include exercises that require no equipment
            queryset = queryset.filter(Q(equipment='None') | Q(equipment__in=equipment))
        
        # Filter by primary or secondary muscles (match any in the list)
        muscle_query = Q()
        if primary_muscles:
            for muscle in primary_muscles:
                # Using contains lookup with JSONField
                muscle_query |= Q(primary_muscles__contains=[muscle])
                
        if secondary_muscles:
            for muscle in secondary_muscles:
                # Using contains lookup with JSONField
                muscle_query |= Q(secondary_muscles__contains=[muscle])
                
        if muscle_query:
            queryset = queryset.filter(muscle_query)
        
        # Filter by exact category match
        if category:
            queryset = queryset.filter(category=category)
            
        return queryset

    def __str__(self):  
        return self.name

    class Meta:
        ordering = ['name']


class Workout(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    duration = models.DurationField(blank=True, default=datetime.timedelta(0))
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    exercises = models.ManyToManyField(Exercise, through='WorkoutExercise')

    def __str__(self):
        return self.name

    class Meta:
        ordering = ['-created_at', 'name']


class WorkoutExercise(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workout = models.ForeignKey(Workout, on_delete=models.CASCADE)
    exercise = models.ForeignKey(Exercise, on_delete=models.CASCADE)
    sets = models.PositiveIntegerField(null=True, blank=True, validators=[MinValueValidator(1)])
    reps = models.PositiveIntegerField(null=True, blank=True, validators=[MinValueValidator(1)])
    weight = models.PositiveIntegerField(null=True, blank=True, validators=[MinValueValidator(0)])
    equipment = models.CharField(max_length=100, blank=True, null=True)
    order = models.PositiveIntegerField()
    time = models.DurationField(null=True, blank=True)
    isCompleted = models.BooleanField(default=False)
    class Meta:
        ordering = ['order']

    def __str__(self):
        return f"{self.workout.name} - {self.exercise.name}"


class ExerciseTransferCoefficient(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    from_exercise = models.ForeignKey(
        Exercise,
        on_delete=models.CASCADE,
        related_name='transfer_coefficients_from',
        help_text="The source exercise with a known 1RM."
    )
    to_exercise = models.ForeignKey(
        Exercise,
        on_delete=models.CASCADE,
        related_name='transfer_coefficients_to',
        help_text="The target exercise for which the 1RM is being estimated."
    )
    coefficient = models.FloatField(
        help_text="The transfer coefficient value (e.g., 1RM_to = coefficient * 1RM_from)."
    )
    DERIVATION_METHOD_CHOICES = [
        ('USER_INPUT', 'User Input'),
        ('SYSTEM_CALCULATED', 'System Calculated'),
        ('INITIAL_SEED', 'Initial Seed'),
        # Potentially add more sources like 'EXPERIMENTAL_DATA' if direct experimental values are stored
    ]
    derivation_method = models.CharField(
        max_length=50,
        choices=DERIVATION_METHOD_CHOICES,
        default='INITIAL_SEED',
        help_text="How this transfer coefficient was determined."
    )
    notes = models.TextField(
        blank=True,
        null=True,
        help_text="Optional notes or context about this coefficient."
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['from_exercise', 'to_exercise']
        unique_together = ('from_exercise', 'to_exercise')
        verbose_name = "Exercise Transfer Coefficient"
        verbose_name_plural = "Exercise Transfer Coefficients"

    def __str__(self):
        return f"Transfer: {self.from_exercise.name} to {self.to_exercise.name} ({self.coefficient})"


# --- Cardio Workout Model ----------------------------------------------


class CardioWorkout(models.Model):
    """Represents a cardio session (walk, run, bike, etc.).

    This is deliberately *simpler* than strength workouts.  At present we only
    capture high-level metadata so the generator can schedule cardio days and
    still persist them for analytics / habit tracking.

    The model can be extended later with GPS tracks, intervals, HR stats, etc.
    """

    CARDIO_TYPE_CHOICES = [
        ("walk", "Walk"),
        ("run", "Run"),
        ("bike", "Bike"),
        ("row", "Row"),
        ("swim", "Swim"),
        ("other", "Other"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200, default="Cardio Session")
    cardio_type = models.CharField(max_length=20, choices=CARDIO_TYPE_CHOICES)

    duration = models.DurationField(
        blank=True,
        default=datetime.timedelta(0),
        help_text="Planned duration (00:00:00). Optional for ad-hoc sessions."
    )

    intensity = models.CharField(
        max_length=50,
        blank=True,
        help_text="Optional free-text intensity description (e.g. 'Zone 2')."
    )

    is_treadmill = models.BooleanField(default=False)
    is_outdoor = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.get_cardio_type_display()} ({self.duration})"
