from pathlib import Path

from sim_host.host import SimHost
from sim_host.math3d import Vec3

ROOT = Path(__file__).resolve().parents[1]
VEHICLE = ROOT / "vehicles" / "f9_like.yaml"
ARCHIVE = ROOT.parent


def test_heading_pitch_90_is_radial_up():
    host = SimHost.from_vehicle_yaml(VEHICLE, archive_root=ARCHIVE)
    direction = host.heading(90.0, 90.0)
    up = host.physics.state.position.normalized()
    vec = Vec3(direction.vector.x, direction.vector.y, direction.vector.z)
    assert vec.angle_degrees(up) < 1.0
