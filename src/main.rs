#![no_main]

use bevy::prelude::*;
use rand::Rng;
use wasm_bindgen::prelude::*;

#[derive(Component)]
struct Player {
    velocity: Vec3,
    is_grounded: bool,
}

#[derive(Component)]
struct FollowCamera;

#[wasm_bindgen(start)]
pub fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_systems(Startup, setup)
        .add_systems(Update, (move_player, apply_gravity, camera_follow))
        .run();
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
) {
    // Spawn a cube (player)
    commands.spawn((
        Player {
            velocity: Vec3::ZERO,
            is_grounded: true,
        },
        Mesh3d(meshes.add(Mesh::from(Cuboid::new(1.0, 1.0, 1.0)))),
        MeshMaterial3d(materials.add(Color::srgb(0.8, 0.7, 0.6))),
        Transform::from_xyz(0.0, 0.5, 8.0),
    ));

    // Add a camera
    commands.spawn((
        FollowCamera,
        Camera3d::default(),
        Transform::from_xyz(-2.5, 4.5, 9.0).looking_at(Vec3::ZERO, Vec3::Y),
    ));

    // Add a light
    commands.spawn((
        PointLight {
            shadows_enabled: true,
            ..default()
        },
        Transform::from_xyz(4.0, 8.0, 4.0),
    ));

    // Add a platform (thick plane)
    commands.spawn((
        Mesh3d(meshes.add(Mesh::from(Cuboid::new(8.0, 0.5, 20.0)))),
        MeshMaterial3d(materials.add(Color::srgb(0.3, 0.5, 0.3))),
        Transform::from_xyz(0.0, -0.25, 0.0),
    ));
}

fn move_player(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut query: Query<(&mut Transform, &mut Player)>,
    time: Res<Time>,
) {
    for (mut transform, mut player) in &mut query {
        // Horizontal movement (left/right only)
        let mut horizontal_movement = 0.0;

        if keyboard_input.pressed(KeyCode::KeyA) {
            horizontal_movement -= 1.0;
        }
        if keyboard_input.pressed(KeyCode::KeyD) {
            horizontal_movement += 1.0;
        }

        // Apply horizontal movement
        transform.translation.x += horizontal_movement * 8.0 * time.delta_secs();

        // Jump input
        if keyboard_input.just_pressed(KeyCode::Space) && player.is_grounded {
            player.velocity.y = 12.0; // Jump velocity
            player.is_grounded = false;
        }
    }
}

fn camera_follow(
    player_query: Query<&Transform, (With<Player>, Without<FollowCamera>)>,
    mut camera_query: Query<&mut Transform, (With<FollowCamera>, Without<Player>)>,
    time: Res<Time>,
) {
    if let Ok(player_transform) = player_query.single() {
        for mut camera_transform in &mut camera_query {
            let offset = Vec3::new(0.0, 4.5, 9.0);
            let target_position = player_transform.translation + offset;

            // Smooth interpolation with lerp factor
            let lerp_factor = 2.0 * time.delta_secs();
            camera_transform.translation = camera_transform
                .translation
                .lerp(target_position, lerp_factor);
            camera_transform.look_at(player_transform.translation, Vec3::Y);
        }
    }
}

fn apply_gravity(mut query: Query<(&mut Transform, &mut Player)>, time: Res<Time>) {
    for (mut transform, mut player) in &mut query {
        // Apply gravity
        player.velocity.y -= 30.0 * time.delta_secs(); // Gravity force

        // Apply velocity to position
        transform.translation += player.velocity * time.delta_secs();

        // Check if player is on the plane (roughly)
        let plane_width = 4.0; // Half the width of the 8.0 wide platform
        let plane_length = 10.0; // Half the length of the 20.0 long platform
        let is_on_plane = transform.translation.x.abs() <= plane_width
            && transform.translation.z.abs() <= plane_length;

        // Ground collision only if on the plane
        if is_on_plane && transform.translation.y <= 0.5 {
            transform.translation.y = 0.5;
            player.velocity.y = 0.0;
            player.is_grounded = true;
        } else if !is_on_plane {
            player.is_grounded = false;
        }

        // If player falls too far below the plane, teleport back
        if transform.translation.y < -10.0 {
            transform.translation = Vec3::new(0.0, 0.5, 8.0);
            player.velocity = Vec3::ZERO;
            player.is_grounded = true;
        }
    }
}
