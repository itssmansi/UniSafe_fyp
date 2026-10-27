import React from 'react';

const createMotionComponent = (Tag) => {
  return React.forwardRef(({
    variants,
    initial,
    animate,
    exit,
    transition,
    whileHover,
    whileTap,
    whileInView,
    viewport,
    ...props
  }, ref) => {
    return <Tag ref={ref} {...props} />;
  });
};

export const motion = new Proxy({}, {
  get: (_, prop) => createMotionComponent(prop)
});

export const AnimatePresence = ({ children }) => <>{children}</>;

export default motion;
