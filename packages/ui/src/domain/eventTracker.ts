type TrackEventOpts = {
  name: string;
  data?: EventData;
};

type EventData = {
  [key: string]: unknown;
};

interface EventTracker {
  Signup(id: string);

  Login(id: string);

  Track(opts: TrackEventOpts);
}

type EventNames = {
  [key: string]: {
    [key: string]: string;
  };
};

const EVENTS: EventNames = {
  HOME: {
    VIEW: "Home View",
  },
  TOAST: {
    SUCCESS: "Toast Success",
    WARNING: "Toast Warning",
    FAILURE: "Toast Failure",
  },
};

export { TrackEventOpts, EventData, EventTracker, EVENTS };
