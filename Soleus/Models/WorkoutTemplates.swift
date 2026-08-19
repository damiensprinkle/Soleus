import Foundation

struct WorkoutTemplate {
    struct TemplateExercise {
        let name: String
        let sets: Int
        let reps: Int32
        let weight: Float
        let time: Int32
        let distance: Float
        let exerciseQuantifier: String
        let exerciseMeasurement: String
        let notes: String?

        init(
            name: String,
            sets: Int,
            reps: Int32 = 0,
            weight: Float = 0,
            time: Int32 = 0,
            distance: Float = 0,
            exerciseQuantifier: String = "Reps",
            exerciseMeasurement: String = "Weight",
            notes: String? = nil
        ) {
            self.name = name
            self.sets = sets
            self.reps = reps
            self.weight = weight
            self.time = time
            self.distance = distance
            self.exerciseQuantifier = exerciseQuantifier
            self.exerciseMeasurement = exerciseMeasurement
            self.notes = notes
        }
    }

    let name: String
    let exercises: [TemplateExercise]

    func toWorkoutDetails() -> [WorkoutDetailInput] {
        exercises.enumerated().map { index, exercise in
            let setInputs = (0..<exercise.sets).map { setIndex in
                SetInput(
                    id: UUID(),
                    reps: exercise.reps,
                    weight: exercise.weight,
                    time: exercise.time,
                    distance: exercise.distance,
                    isCompleted: false,
                    setIndex: Int32(setIndex),
                    exerciseQuantifier: exercise.exerciseQuantifier,
                    exerciseMeasurement: exercise.exerciseMeasurement
                )
            }
            return WorkoutDetailInput(
                id: UUID(),
                exerciseId: UUID(),
                exerciseName: exercise.name,
                notes: exercise.notes,
                orderIndex: Int32(index),
                sets: setInputs,
                exerciseQuantifier: exercise.exerciseQuantifier,
                exerciseMeasurement: exercise.exerciseMeasurement
            )
        }
    }

    static let allTemplates: [WorkoutTemplate] = [
        WorkoutTemplate(name: "Push", exercises: [
            TemplateExercise(name: "Barbell Bench Press",      sets: 4, reps: 8,  weight: 135),
            TemplateExercise(name: "Incline Dumbbell Press",   sets: 3, reps: 10, weight: 40),
            TemplateExercise(name: "Dumbbell Shoulder Press",  sets: 3, reps: 8,  weight: 35),
            TemplateExercise(name: "Dumbbell Lateral Raise",   sets: 3, reps: 12, weight: 15),
            TemplateExercise(name: "Tricep Rope Pushdown",     sets: 3, reps: 10, weight: 50),
        ]),
        WorkoutTemplate(name: "Pull", exercises: [
            TemplateExercise(name: "Lat Pulldown",             sets: 4, reps: 8,  weight: 120),
            TemplateExercise(name: "Barbell Bent Over Row",    sets: 4, reps: 8,  weight: 115),
            TemplateExercise(name: "Seated Cable Row",         sets: 3, reps: 10, weight: 110),
            TemplateExercise(name: "Face Pull",                sets: 3, reps: 12, weight: 40),
            TemplateExercise(name: "Dumbbell Bicep Curl",      sets: 3, reps: 10, weight: 25),
        ]),
        WorkoutTemplate(name: "Legs", exercises: [
            TemplateExercise(name: "Barbell Squat",            sets: 4, reps: 8,  weight: 185),
            TemplateExercise(name: "Romanian Deadlift",        sets: 3, reps: 8,  weight: 155),
            TemplateExercise(name: "Leg Press",                sets: 3, reps: 10, weight: 270),
            TemplateExercise(name: "Leg Curl",                 sets: 3, reps: 12, weight: 90),
            TemplateExercise(name: "Standing Calf Raise",      sets: 4, reps: 12, weight: 140),
        ]),
        WorkoutTemplate(name: "Chest", exercises: [
            TemplateExercise(name: "Barbell Bench Press",      sets: 4, reps: 8,  weight: 135),
            TemplateExercise(name: "Incline Dumbbell Press",   sets: 3, reps: 10, weight: 40),
            TemplateExercise(name: "Dumbbell Chest Fly",       sets: 3, reps: 10, weight: 25),
            TemplateExercise(name: "Push Ups",                 sets: 3, reps: 12, weight: 0),
        ]),
        WorkoutTemplate(name: "Back", exercises: [
            TemplateExercise(name: "Deadlift",                 sets: 4, reps: 5,  weight: 225),
            TemplateExercise(name: "Lat Pulldown",             sets: 4, reps: 8,  weight: 120),
            TemplateExercise(name: "Barbell Row",              sets: 3, reps: 8,  weight: 115),
            TemplateExercise(name: "Face Pull",                sets: 3, reps: 12, weight: 40),
        ]),
        WorkoutTemplate(name: "Shoulders", exercises: [
            TemplateExercise(name: "Overhead Barbell Press",   sets: 4, reps: 6,  weight: 95),
            TemplateExercise(name: "Dumbbell Lateral Raise",   sets: 3, reps: 12, weight: 15),
            TemplateExercise(name: "Rear Delt Fly",            sets: 3, reps: 12, weight: 15),
            TemplateExercise(name: "Arnold Press",             sets: 3, reps: 8,  weight: 30),
        ]),
        WorkoutTemplate(name: "Arms", exercises: [
            TemplateExercise(name: "Barbell Curl",             sets: 3, reps: 8,  weight: 65),
            TemplateExercise(name: "Hammer Curl",              sets: 3, reps: 10, weight: 30),
            TemplateExercise(name: "Tricep Dips",              sets: 3, reps: 10, weight: 0),
            TemplateExercise(name: "Rope Pushdown",            sets: 3, reps: 10, weight: 50),
            TemplateExercise(name: "Overhead Tricep Extension",sets: 3, reps: 10, weight: 35),
        ]),
        WorkoutTemplate(name: "Total Body I", exercises: [
            TemplateExercise(name: "Barbell Squat",            sets: 4, reps: 8,  weight: 185),
            TemplateExercise(name: "Bench Press",              sets: 3, reps: 8,  weight: 135),
            TemplateExercise(name: "Lat Pulldown",             sets: 3, reps: 10, weight: 120),
            TemplateExercise(name: "Dumbbell Shoulder Press",  sets: 3, reps: 10, weight: 35),
            TemplateExercise(name: "Plank",                    sets: 3, reps: 30, weight: 0),
        ]),
        WorkoutTemplate(name: "Total Body II", exercises: [
            TemplateExercise(name: "Deadlift",                 sets: 4, reps: 5,  weight: 225),
            TemplateExercise(name: "Incline Dumbbell Press",   sets: 3, reps: 10, weight: 40),
            TemplateExercise(name: "Seated Cable Row",         sets: 3, reps: 10, weight: 110),
            TemplateExercise(name: "Dumbbell Lateral Raise",   sets: 3, reps: 12, weight: 15),
            TemplateExercise(name: "Hanging Leg Raise",        sets: 3, reps: 10, weight: 0),
        ]),
        WorkoutTemplate(name: "Warmup", exercises: [
            TemplateExercise(name: "Jump Rope",          sets: 1, reps: 1, time: 60,  exerciseQuantifier: "Reps", exerciseMeasurement: "Time"),
            TemplateExercise(name: "Arm Circles",        sets: 1, reps: 30),
            TemplateExercise(name: "Bodyweight Squats",  sets: 1, reps: 15),
            TemplateExercise(name: "Walking Lunges",     sets: 1, reps: 20),
            TemplateExercise(name: "Push Ups",           sets: 1, reps: 10),
            TemplateExercise(name: "Plank",              sets: 1, reps: 1, time: 30,  exerciseQuantifier: "Reps", exerciseMeasurement: "Time"),
        ]),
        WorkoutTemplate(name: "Cardio", exercises: [
            TemplateExercise(name: "Treadmill Jog",  sets: 1, time: 600, distance: 0.5,  exerciseQuantifier: "Distance", exerciseMeasurement: "Time"),
            TemplateExercise(name: "Cycling",        sets: 1, time: 600, distance: 0.5,             exerciseQuantifier: "Distance", exerciseMeasurement: "Time"),
            TemplateExercise(name: "Rowing Machine", sets: 1, time: 400, distance: 0.5,             exerciseQuantifier: "Distance", exerciseMeasurement: "Time"),
            TemplateExercise(name: "Burpees",        sets: 3, reps: 12, weight: 0),
        ]),
        WorkoutTemplate(name: "Daily Posture & Mobility", exercises: [
            TemplateExercise(name: "Chin Tucks", sets: 3, reps: 10,
                notes: "Sit upright. Pull chin straight back as if making a double chin. Hold 5s each rep. Releases the suboccipitals."),
            TemplateExercise(name: "Levator/Upper Trap Stretch", sets: 2, reps: 1, time: 30, exerciseQuantifier: "Reps", exerciseMeasurement: "Time",
                notes: "Sit on one hand, turn head 45 degrees away, look down toward armpit. Hold 30s per side."),
            TemplateExercise(name: "Doorway Pec Stretch", sets: 2, reps: 1, time: 30, exerciseQuantifier: "Reps", exerciseMeasurement: "Time",
                notes: "Forearms on doorframe at 90 degrees. Step forward until chest stretches. Hold 30s."),
            TemplateExercise(name: "Thoracic Spine Foam Rolling", sets: 1, reps: 1, time: 90, exerciseQuantifier: "Reps", exerciseMeasurement: "Time",
                notes: "Lie back over foam roller on mid-back, support head, extend back gently."),
        ]),
        WorkoutTemplate(name: "Posture Day 1: Upper Back", exercises: [
            TemplateExercise(name: "Face Pulls (Cable with Rope)", sets: 3, reps: 15, weight: 0,
                notes: "Pull rope toward eyes, rotating knuckles back; squeeze shoulder blades down."),
            TemplateExercise(name: "Chest-Supported Dumbbell Row", sets: 3, reps: 12, weight: 0,
                notes: "Prevents swinging; focus on driving elbows back and pulling shoulder blades together."),
            TemplateExercise(name: "Prone Y-T-W Raises", sets: 3, reps: 10, weight: 0,
                notes: "On an incline bench. Use light dumbbells or bodyweight. Targets lower traps and rear delts."),
            TemplateExercise(name: "Goblet Squat", sets: 3, reps: 10, weight: 0,
                notes: "Drives core engagement and upright posture. Keep chest high."),
            TemplateExercise(name: "Farmer's Carries", sets: 3, weight: 0, distance: 40, exerciseQuantifier: "Distance", exerciseMeasurement: "Weight",
                notes: "Walk upright with heavy dumbbells. Retract shoulders without shrugging up."),
        ]),
        WorkoutTemplate(name: "Posture Day 2: Rear Chain", exercises: [
            TemplateExercise(name: "Lat Pulldowns (Neutral Grip)", sets: 3, reps: 12, weight: 0,
                notes: "Pull to upper chest; pull elbows down toward your back pockets."),
            TemplateExercise(name: "Single-Arm Cable / Band Rows", sets: 3, reps: 12, weight: 0,
                notes: "Focus on full extension and controlled rotation without hunching."),
            TemplateExercise(name: "Dumbbell Romanian Deadlift", sets: 3, reps: 10, weight: 0,
                notes: "Strengthens posterior chain. Keep shoulders set back throughout."),
            TemplateExercise(name: "Cable External Rotations", sets: 3, reps: 15, weight: 0,
                notes: "Keeps rotator cuff strong and counteracts rounded-forward shoulders."),
            TemplateExercise(name: "Dead Bug or Pallof Press", sets: 3, reps: 10, weight: 0,
                notes: "Core stability prevents lower back arching, which spills into upper posture."),
        ]),
    ]
}
