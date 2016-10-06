-- MySQL dump 10.13  Distrib 5.5.44, for debian-linux-gnu (armv7l)
--
-- Host: localhost    Database: scope
-- ------------------------------------------------------
-- Server version	5.5.44-0+deb7u1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `data`
--

DROP TABLE IF EXISTS `data`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `data` (
  `i` smallint(5) unsigned NOT NULL DEFAULT '0',
  `time` int(10) unsigned DEFAULT NULL,
  `dac` smallint(5) unsigned DEFAULT NULL,
  `adc` smallint(5) unsigned DEFAULT NULL,
  PRIMARY KEY (`i`)
) ENGINE=MEMORY DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `parameters`
--

DROP TABLE IF EXISTS `parameters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `parameters` (
  `addr` int(11) NOT NULL DEFAULT '0',
  `name` varchar(20) NOT NULL,
  `value` int(11) NOT NULL,
  PRIMARY KEY (`addr`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `parameters`
--

LOCK TABLES `parameters` WRITE;
/*!40000 ALTER TABLE `parameters` DISABLE KEYS */;
INSERT INTO `parameters` VALUES (0,'RUN',1),(1,'OPENCLOSE',1),(2,'XLOCK',5000),(3,'YLOCK',2048),(4,'TIMEX_TIMEY_XY',1),(8,'ADC_CLKDIV',0),(9,'ADC_AVERAGE',0),(10,'ADC_OPENDELAY',10),(11,'ADC_CLOSEDDELAY',20),(13,'OPENAMPL',10000),(14,'SCANPOINT',0),(15,'SLOW_ACCUM',11),(16,'PGAIN',0),(17,'IGAIN',0),(18,'DGAIN',0),(19,'IRESET',0),(20,'AUTO_IRESET',0),(23,'LOCKSLOPE',0),(24,'AUTOLOCK_EN',0),(25,'AUTOLOCK_LT_GT',0),(26,'AUTOLOCK_POINT',200),(27,'PGAIN2',0),(100,'MODE',2),(110,'MUXOUT',0),(111,'MUXIN',0);
/*!40000 ALTER TABLE `parameters` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2016-09-13  8:51:50
