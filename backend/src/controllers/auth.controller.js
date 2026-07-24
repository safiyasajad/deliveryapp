const { loginUser } = require('../services/auth.service');

async function login(req, res, next) {
  try {
    const result = await loginUser(req.body);

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

module.exports = {
  login,
};
