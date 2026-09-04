import { createResetGate } from './resetGate';

const setup = () => {
  const state = { inFlight: false, open: true, rewinds: 0 };
  const gate = createResetGate({
    inFlight: () => state.inFlight,
    isOpen: () => state.open,
    rewind: () => state.rewinds++,
  });
  return { state, gate };
};

describe('createResetGate', () => {
  it('rewinds at once while nothing is in flight', () => {
    const { state, gate } = setup();

    expect(gate.request()).toBe(true);
    expect(state.rewinds).toBe(1);
  });

  it('refuses a rewind while the action is in flight', () => {
    // The wallet prompt is open: rewinding here is what re-offered the same claim
    const { state, gate } = setup();
    state.inFlight = true;

    expect(gate.request()).toBe(false);
    expect(state.rewinds).toBe(0);
  });

  it('applies the refused rewind once the action settles with the dialog closed', () => {
    const { state, gate } = setup();
    state.inFlight = true;
    state.open = false;
    gate.request();

    state.inFlight = false;
    gate.settle();

    expect(state.rewinds).toBe(1);
  });

  it('does not rewind under a user who reopened the dialog meanwhile', () => {
    // They are looking at the confirm step; after a rejected signature they retry from there
    const { state, gate } = setup();
    state.inFlight = true;
    state.open = false;
    gate.request();
    state.open = true;

    state.inFlight = false;
    gate.settle();

    expect(state.rewinds).toBe(0);
  });

  it('keeps waiting while the action is still in flight at settle time', () => {
    // A claim whose transaction is now pending: the click settled, the outcome has not
    const { state, gate } = setup();
    state.inFlight = true;
    state.open = false;
    gate.request();

    gate.settle();
    expect(state.rewinds).toBe(0);

    state.inFlight = false;
    gate.settle();
    expect(state.rewinds).toBe(1);
  });

  it('does nothing at settle when no rewind was refused', () => {
    const { state, gate } = setup();
    state.open = false;

    gate.settle();

    expect(state.rewinds).toBe(0);
  });

  it('applies a refused rewind only once', () => {
    const { state, gate } = setup();
    state.inFlight = true;
    state.open = false;
    gate.request();
    state.inFlight = false;

    gate.settle();
    gate.settle();

    expect(state.rewinds).toBe(1);
  });

  it('forgets a refused rewind once a later request went through', () => {
    const { state, gate } = setup();
    state.inFlight = true;
    gate.request();
    state.inFlight = false;
    gate.request();
    state.open = false;

    gate.settle();

    expect(state.rewinds).toBe(1);
  });
});
