use bevy::prelude::*;

#[derive(Component)]
struct Player;

#[derive(Component)]
struct FollowCamera;

#[derive(Component)]
struct Velocity {
    y: f32,
}

#[derive(Component)]
struct FallTimer {
    timer: Timer,
    original_position: Vec3,
}

fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_systems(Startup, setup)
        .add_systems(Update, (player_movement, apply_gravity, camera_follow, handle_fall_timer))
        .run();
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
) {
    commands.spawn((
        Camera3dBundle {
            transform: Transform::from_xyz(-2.0, 2.5, 5.0).looking_at(Vec3::ZERO, Vec3::Y),
            ..default()
        },
        FollowCamera,
    ));

    // player0
    commands.spawn((
        PbrBundle {
            mesh: meshes.add(Cuboid::new(1.0, 2.0, 1.0)),
            material: materials.add(Color::srgb_u8(124, 144, 255)),
            transform: Transform::from_xyz(0.0, 0.5, 0.0),
            ..default()
        },
        Player,
        Velocity { y: 0.0 },
        FallTimer {
            timer: Timer::from_seconds(5.0, TimerMode::Once),
            original_position: Vec3::new(0.0, 0.5, 0.0),
        },
    ));

    // ground
    commands.spawn(PbrBundle {
        mesh: meshes.add(Plane3d::default().mesh().size(5.0, 5.0)),
        material: materials.add(Color::srgb_u8(60, 120, 60)),
        ..default()
    });

    // light 1
    commands.spawn(PointLightBundle {
        point_light: PointLight {
            shadows_enabled: true,
            ..default()
        },
        transform: Transform::from_xyz(4.0, 8.0, 4.0),
        ..default()
    });

    // light 2
    commands.spawn(PointLightBundle {
        point_light: PointLight {
            shadows_enabled: true,
            ..default()
        },
        transform: Transform::from_xyz(-4.0, 8.0, 4.0),
        ..default()
    });

    println!("Hello, Bevy world!!!");
}

fn player_movement(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut query: Query<(&mut Transform, &mut Velocity), With<Player>>,
    time: Res<Time>,
) {
    const MAP_BOUNDARY: f32 = 2.5;
    
    for (mut transform, mut velocity) in query.iter_mut() {
        let speed = 5.0;
        let movement_speed = speed * time.delta_seconds();

        for key in keyboard_input.get_pressed() {
            match key {
                KeyCode::KeyW => transform.translation.z -= movement_speed,
                KeyCode::KeyS => transform.translation.z += movement_speed,
                KeyCode::KeyA => transform.translation.x -= movement_speed,
                KeyCode::KeyD => transform.translation.x += movement_speed,
                _ => {}
            }
        }


        if keyboard_input.just_pressed(KeyCode::Space) && transform.translation.y <= 1.0 {
            velocity.y = 12.0;
        }
    }
}

fn apply_gravity(
    mut query: Query<(&mut Transform, &mut Velocity, &mut FallTimer), With<Player>>,
    time: Res<Time>,
) {
    const GRAVITY: f32 = -25.0;
    const GROUND_Y: f32 = 1.0;
    const MAP_BOUNDARY: f32 = 2.5;

    for (mut transform, mut velocity, mut fall_timer) in query.iter_mut() {
        velocity.y += GRAVITY * time.delta_seconds();
        
        transform.translation.y += velocity.y * time.delta_seconds();
        
        if transform.translation.y <= GROUND_Y {
            let x = transform.translation.x;
            let z = transform.translation.z;
            
            if x.abs() > MAP_BOUNDARY || z.abs() > MAP_BOUNDARY {
                // Player is outside map bounds, start fall timer
                fall_timer.timer.tick(time.delta());
            } else {
                // Player is on the ground within map bounds
                transform.translation.y = GROUND_Y;
                velocity.y = 0.0;
                fall_timer.timer.reset();
            }
        } else {
            // Player is in the air, reset fall timer
            fall_timer.timer.reset();
        }
    }
}

fn camera_follow(
    player_query: Query<&Transform, (With<Player>, Without<FollowCamera>)>,
    mut camera_query: Query<&mut Transform, (With<FollowCamera>, Without<Player>)>,
) {
    if let Ok(player_transform) = player_query.get_single() {
        for mut camera_transform in camera_query.iter_mut() {
            let offset = Vec3::new(0.0, 3.5, 6.0);
            camera_transform.translation = player_transform.translation + offset;
            camera_transform.look_at(player_transform.translation, Vec3::Y);
        }
    }
}

fn handle_fall_timer(
    mut query: Query<(&mut Transform, &mut Velocity, &mut FallTimer), With<Player>>,
) {
    for (mut transform, mut velocity, mut fall_timer) in query.iter_mut() {
        if fall_timer.timer.finished() {
            // Respawn player to original position
            transform.translation = fall_timer.original_position;
            velocity.y = 0.0;
            fall_timer.timer.reset();
        }
    }
}
