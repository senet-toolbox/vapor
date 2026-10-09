//! Ready-made animations: `Animation.fadeIn("name")` and friends.

const Animation = @import("../Animation.zig");

pub fn fadeIn(name: []const u8) Animation {
    return Animation.init(name)
        .prop(.opacity, 0, 1)
        .duration(150)
        .easing(.easeInOut)
        .fill(.forwards);
}

pub fn fadeOut(name: []const u8) Animation {
    return Animation.init(name)
        .prop(.opacity, 1, 0)
        .duration(150)
        .easing(.easeInOut)
        .fill(.forwards);
}

pub fn slideInLeft(name: []const u8, distance: f32) Animation {
    return Animation.init(name)
        .prop(.translateX, -distance, 0)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn slideInRight(name: []const u8, distance: f32) Animation {
    return Animation.init(name)
        .prop(.translateX, distance, 0)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn slideInUp(name: []const u8, distance: f32) Animation {
    return Animation.init(name)
        .prop(.translateY, distance, 0)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn slideInDown(name: []const u8, distance: f32) Animation {
    return Animation.init(name)
        .prop(.translateY, -distance, 0)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn slideOutLeft(name: []const u8, distance: f32) Animation {
    return Animation.init(name)
        .prop(.translateX, 0, -distance)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn slideOutRight(name: []const u8, distance: f32) Animation {
    return Animation.init(name)
        .prop(.translateX, 0, distance)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn slideOutUp(name: []const u8, distance: f32) Animation {
    return Animation.init(name)
        .prop(.translateY, 0, -distance)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn slideOutDown(name: []const u8, distance: f32) Animation {
    return Animation.init(name)
        .prop(.translateY, 0, distance)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn zoomIn(name: []const u8) Animation {
    return Animation.init(name)
        .prop(.scale, 0, 1)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn zoomOut(name: []const u8) Animation {
    return Animation.init(name)
        .prop(.scale, 1, 0)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn spin(name: []const u8) Animation {
    return Animation.init(name)
        .prop(.rotate, 0, 360)
        .infinite();
}

pub fn pulse(name: []const u8) Animation {
    return Animation.init(name)
        .prop(.scale, 1, 1.05)
        .dir(.alternate)
        .infinite();
}

// ============================================
// ATTENTION / EMPHASIS ANIMATIONS
// ============================================

pub fn bounce(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .translateY = 0 })
        .at(20).setAll(.{ .translateY = -30 })
        .at(40).setAll(.{ .translateY = 0 })
        .at(60).setAll(.{ .translateY = -15 })
        .at(80).setAll(.{ .translateY = 0 })
        .at(100).setAll(.{ .translateY = 0 })
        .easing(.easeOut)
        .fill(.both);
}

pub fn shake(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.translateX, 0)
        .at(10).set(.translateX, -10)
        .at(20).set(.translateX, 10)
        .at(30).set(.translateX, -10)
        .at(40).set(.translateX, 10)
        .at(50).set(.translateX, -10)
        .at(60).set(.translateX, 10)
        .at(70).set(.translateX, -10)
        .at(80).set(.translateX, 10)
        .at(90).set(.translateX, -10)
        .at(100).set(.translateX, 0)
        .duration(500);
}

pub fn shakeY(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.translateY, 0)
        .at(10).set(.translateY, -10)
        .at(20).set(.translateY, 10)
        .at(30).set(.translateY, -10)
        .at(40).set(.translateY, 10)
        .at(50).set(.translateY, -10)
        .at(60).set(.translateY, 10)
        .at(70).set(.translateY, -10)
        .at(80).set(.translateY, 10)
        .at(90).set(.translateY, -10)
        .at(100).set(.translateY, 0)
        .duration(500);
}

pub fn wobble(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .translateX = 0, .rotate = 0 })
        .at(15).setAll(.{ .translateX = -25, .rotate = -5 })
        .at(30).setAll(.{ .translateX = 20, .rotate = 3 })
        .at(45).setAll(.{ .translateX = -15, .rotate = -3 })
        .at(60).setAll(.{ .translateX = 10, .rotate = 2 })
        .at(75).setAll(.{ .translateX = -5, .rotate = -1 })
        .at(100).setAll(.{ .translateX = 0, .rotate = 0 })
        .duration(800);
}

pub fn jello(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.skewX, 0)
        .at(11).set(.skewX, 0)
        .at(22).set(.skewX, -12.5)
        .at(33).set(.skewX, 6.25)
        .at(44).set(.skewX, -3.125)
        .at(55).set(.skewX, 1.5625)
        .at(66).set(.skewX, -0.78125)
        .at(77).set(.skewX, 0.390625)
        .at(88).set(.skewX, -0.1953125)
        .at(100).set(.skewX, 0)
        .duration(900);
}

pub fn heartbeat(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.scale, 1)
        .at(14).set(.scale, 1.3)
        .at(28).set(.scale, 1)
        .at(42).set(.scale, 1.3)
        .at(70).set(.scale, 1)
        .duration(1300)
        .easing(.easeInOut);
}

pub fn rubberBand(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .scaleX = 1, .scaleY = 1 })
        .at(30).setAll(.{ .scaleX = 1.25, .scaleY = 0.75 })
        .at(40).setAll(.{ .scaleX = 0.75, .scaleY = 1.25 })
        .at(50).setAll(.{ .scaleX = 1.15, .scaleY = 0.85 })
        .at(65).setAll(.{ .scaleX = 0.95, .scaleY = 1.05 })
        .at(75).setAll(.{ .scaleX = 1.05, .scaleY = 0.95 })
        .at(100).setAll(.{ .scaleX = 1, .scaleY = 1 })
        .duration(800);
}

pub fn tada(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .scale = 1, .rotate = 0 })
        .at(10).setAll(.{ .scale = 0.9, .rotate = -3 })
        .at(20).setAll(.{ .scale = 0.9, .rotate = -3 })
        .at(30).setAll(.{ .scale = 1.1, .rotate = 3 })
        .at(40).setAll(.{ .scale = 1.1, .rotate = -3 })
        .at(50).setAll(.{ .scale = 1.1, .rotate = 3 })
        .at(60).setAll(.{ .scale = 1.1, .rotate = -3 })
        .at(70).setAll(.{ .scale = 1.1, .rotate = 3 })
        .at(80).setAll(.{ .scale = 1.1, .rotate = -3 })
        .at(90).setAll(.{ .scale = 1.1, .rotate = 3 })
        .at(100).setAll(.{ .scale = 1, .rotate = 0 })
        .duration(1000);
}

pub fn swing(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.rotate, 0)
        .at(20).set(.rotate, 15)
        .at(40).set(.rotate, -10)
        .at(60).set(.rotate, 5)
        .at(80).set(.rotate, -5)
        .at(100).set(.rotate, 0)
        .duration(800)
        .easing(.easeInOut);
}

// ============================================
// ENTRANCE ANIMATIONS
// ============================================

pub fn bounceIn(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .scale = 0.3 })
        .at(20).setAll(.{ .scale = 1.1 })
        .at(40).setAll(.{ .scale = 0.9 })
        .at(60).setAll(.{ .opacity = 1, .scale = 1.03 })
        .at(80).setAll(.{ .scale = 0.97 })
        .at(100).setAll(.{ .opacity = 1, .scale = 1 })
        .duration(750)
        .fill(.both);
}

pub fn bounceInDown(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .translateY = -3000 })
        .at(60).setAll(.{ .opacity = 1, .translateY = 25 })
        .at(75).setAll(.{ .translateY = -10 })
        .at(90).setAll(.{ .translateY = 5 })
        .at(100).setAll(.{ .translateY = 0 })
        .easing(.easeOutCubic)
        .fill(.both);
}

pub fn bounceInUp(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .translateY = 3000 })
        .at(60).setAll(.{ .opacity = 1, .translateY = -25 })
        .at(75).setAll(.{ .translateY = 10 })
        .at(90).setAll(.{ .translateY = -5 })
        .at(100).setAll(.{ .translateY = 0 })
        .easing(.easeOutCubic)
        .fill(.both);
}

pub fn flipIn(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .rotateY = 90 })
        .at(40).setAll(.{ .rotateY = -20 })
        .at(60).setAll(.{ .rotateY = 10 })
        .at(80).setAll(.{ .opacity = 1, .rotateY = -5 })
        .at(100).setAll(.{ .rotateY = 0 })
        .duration(750)
        .easing(.easeInOut)
        .fill(.both);
}

pub fn flipInX(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .rotateX = 90 })
        .at(40).setAll(.{ .rotateX = -20 })
        .at(60).setAll(.{ .rotateX = 10 })
        .at(80).setAll(.{ .opacity = 1, .rotateX = -5 })
        .at(100).setAll(.{ .rotateX = 0 })
        .duration(750)
        .easing(.easeInOut)
        .fill(.both);
}

pub fn rotateIn(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .rotate = -200 })
        .at(100).setAll(.{ .opacity = 1, .rotate = 0 })
        .easing(.easeInOut)
        .fill(.both);
}

pub fn rollIn(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .translateX = -100, .rotate = -120 })
        .at(100).setAll(.{ .opacity = 1, .translateX = 0, .rotate = 0 })
        .duration(800)
        .fill(.both);
}

pub fn lightSpeedIn(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .translateX = 100, .skewX = -30 })
        .at(60).setAll(.{ .opacity = 1, .skewX = 20 })
        .at(80).setAll(.{ .skewX = -5 })
        .at(100).setAll(.{ .translateX = 0, .skewX = 0 })
        .easing(.easeOut)
        .fill(.both);
}

pub fn expandIn(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .scaleX = 0, .scaleY = 1 })
        .at(100).setAll(.{ .opacity = 1, .scaleX = 1, .scaleY = 1 })
        .easing(.easeOut)
        .fill(.both);
}

pub fn expandInY(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0, .scaleX = 1, .scaleY = 0 })
        .at(100).setAll(.{ .opacity = 1, .scaleX = 1, .scaleY = 1 })
        .easing(.easeOut)
        .fill(.both);
}

// ============================================
// EXIT ANIMATIONS
// ============================================

pub fn bounceOut(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 1, .scale = 1 })
        .at(20).setAll(.{ .scale = 0.9 })
        .at(50).setAll(.{ .opacity = 1, .scale = 1.1 })
        .at(55).setAll(.{ .opacity = 1, .scale = 1.1 })
        .at(100).setAll(.{ .opacity = 0, .scale = 0.3 })
        .duration(750)
        .fill(.both);
}

pub fn bounceOutDown(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .translateY = 0 })
        .at(20).setAll(.{ .translateY = -10 })
        .at(40).setAll(.{ .opacity = 1, .translateY = 20 })
        .at(45).setAll(.{ .opacity = 1, .translateY = 20 })
        .at(100).setAll(.{ .opacity = 0, .translateY = 2000 })
        .fill(.both);
}

pub fn bounceOutUp(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .translateY = 0 })
        .at(20).setAll(.{ .translateY = 10 })
        .at(40).setAll(.{ .opacity = 1, .translateY = -20 })
        .at(45).setAll(.{ .opacity = 1, .translateY = -20 })
        .at(100).setAll(.{ .opacity = 0, .translateY = -2000 })
        .fill(.both);
}

pub fn flipOut(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 1, .rotateY = 0 })
        .at(30).setAll(.{ .opacity = 1, .rotateY = -20 })
        .at(100).setAll(.{ .opacity = 0, .rotateY = 90 })
        .duration(600)
        .fill(.both);
}

pub fn rotateOut(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 1, .rotate = 0 })
        .at(100).setAll(.{ .opacity = 0, .rotate = 200 })
        .easing(.easeInOut)
        .fill(.both);
}

pub fn rollOut(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 1, .translateX = 0, .rotate = 0 })
        .at(100).setAll(.{ .opacity = 0, .translateX = 100, .rotate = 120 })
        .duration(800)
        .fill(.both);
}

pub fn lightSpeedOut(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 1, .translateX = 0, .skewX = 0 })
        .at(100).setAll(.{ .opacity = 0, .translateX = 100, .skewX = 30 })
        .easing(.easeIn)
        .fill(.both);
}

pub fn shrinkOut(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 1, .scale = 1 })
        .at(100).setAll(.{ .opacity = 0, .scale = 0 })
        .easing(.easeIn)
        .fill(.both);
}

pub fn hinge(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 1, .rotate = 0 })
        .at(20).setAll(.{ .rotate = 80 })
        .at(40).setAll(.{ .rotate = 60 })
        .at(60).setAll(.{ .rotate = 80 })
        .at(80).setAll(.{ .opacity = 1, .rotate = 60, .translateY = 0 })
        .at(100).setAll(.{ .opacity = 0, .rotate = 60, .translateY = 700 })
        .duration(2000)
        .easing(.easeInOut)
        .fill(.both);
}

// ============================================
// BACKGROUND / SPECIAL ANIMATIONS
// ============================================

pub fn flash(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.opacity, 1)
        .at(25).set(.opacity, 0)
        .at(50).set(.opacity, 1)
        .at(75).set(.opacity, 0)
        .at(100).set(.opacity, 1)
        .duration(750);
}

pub fn blink(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.opacity, 1)
        .at(50).set(.opacity, 0)
        .at(100).set(.opacity, 1)
        .duration(1000)
        .infinite();
}

pub fn glow(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.brightness, 1)
        .at(50).set(.brightness, 1.3)
        .at(100).set(.brightness, 1)
        .dir(.alternate)
        .infinite();
}

pub fn float(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.translateY, 0)
        .at(50).set(.translateY, -20)
        .at(100).set(.translateY, 0)
        .easing(.easeInOut)
        .dir(.alternate)
        .infinite();
}

pub fn sway(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.rotate, -3)
        .at(50).set(.rotate, 3)
        .at(100).set(.rotate, -3)
        .easing(.easeInOut)
        .infinite();
}

pub fn breathe(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.scale, 1)
        .at(50).set(.scale, 1.1)
        .at(100).set(.scale, 1)
        .duration(3000)
        .easing(.easeInOut)
        .infinite();
}

pub fn pulseShadow(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.blur, 0)
        .at(50).set(.blur, 10)
        .at(100).set(.blur, 0)
        .duration(2000)
        .easing(.easeInOut)
        .infinite();
}

// ============================================
// LOADING / PROGRESS ANIMATIONS
// ============================================

pub fn spinPulse(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .rotate = 0, .scale = 1 })
        .at(50).setAll(.{ .rotate = 180, .scale = 1.2 })
        .at(100).setAll(.{ .rotate = 360, .scale = 1 })
        .infinite();
}

pub fn pendulum(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.rotate, -45)
        .at(50).set(.rotate, 45)
        .at(100).set(.rotate, -45)
        .easing(.easeInOut)
        .infinite();
}

pub fn morphWidth(name: []const u8, from: f32, to: f32) Animation {
    return Animation.init(name)
        .at(0).set(.width, from)
        .at(50).set(.width, to)
        .at(100).set(.width, from)
        .easing(.easeInOut)
        .infinite();
}

pub fn progressPulse(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .opacity = 0.6, .scaleX = 0.8 })
        .at(50).setAll(.{ .opacity = 1, .scaleX = 1 })
        .at(100).setAll(.{ .opacity = 0.6, .scaleX = 0.8 })
        .easing(.easeInOut)
        .infinite();
}

// ============================================
// TEXT ANIMATIONS
// ============================================

pub fn typewriter(name: []const u8, width: f32) Animation {
    return Animation.init(name)
        .at(0).set(.width, 0)
        .at(100).set(.width, width)
        .easing(.linear)
        .fill(.forwards);
}

pub fn blur(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .blur = 0, .opacity = 1 })
        .at(100).setAll(.{ .blur = 10, .opacity = 0 })
        .fill(.forwards);
}

pub fn unblur(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .blur = 10, .opacity = 0 })
        .at(100).setAll(.{ .blur = 0, .opacity = 1 })
        .fill(.forwards);
}

// ============================================
// 3D-ISH ANIMATIONS
// ============================================

pub fn flip3D(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).set(.rotateY, 0)
        .at(100).set(.rotateY, 360)
        .easing(.easeInOut)
        .infinite();
}

pub fn tilt(name: []const u8, deg: f32) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .rotateX = 0, .rotateY = 0 })
        .at(50).setAll(.{ .rotateX = deg, .rotateY = deg })
        .at(100).setAll(.{ .rotateX = 0, .rotateY = 0 })
        .easing(.easeInOut)
        .infinite();
}

pub fn zoomInRotate(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .scale = 0, .rotate = -180, .opacity = 0 })
        .at(100).setAll(.{ .scale = 1, .rotate = 0, .opacity = 1 })
        .easing(.easeOutBack)
        .fill(.both);
}

pub fn zoomOutRotate(name: []const u8) Animation {
    return Animation.init(name)
        .at(0).setAll(.{ .scale = 1, .rotate = 0, .opacity = 1 })
        .at(100).setAll(.{ .scale = 0, .rotate = 180, .opacity = 0 })
        .easing(.easeInBack)
        .fill(.both);
}
