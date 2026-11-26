from pathlib import Path

from sim_host.host import SimHost

ROOT = Path(__file__).resolve().parents[1]
VEHICLE = ROOT / "vehicles" / "f9_like.yaml"
ARCHIVE = ROOT.parent  # repo root


def test_pad_state():
    host = SimHost.from_vehicle_yaml(VEHICLE, archive_root=ARCHIVE)
    assert host.ship.altitude >= 0
    assert host.ship.altitude < 200
    assert host.ship.mass > 0


def test_thrust_raises_altitude():
    host = SimHost.from_vehicle_yaml(VEHICLE, archive_root=ARCHIVE)
    host.set_throttle(1.0)
    host.release_clamps()
    host.stage()  # ignite
    alt0 = host.ship.altitude
    host.advance(10.0)
    assert host.ship.altitude > alt0 + 50
